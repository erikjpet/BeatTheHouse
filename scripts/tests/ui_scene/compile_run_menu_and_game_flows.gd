extends "res://scripts/tests/ui_scene/compile_environment_layout.gd"

const CageCounterViewModelScript := preload("res://scripts/ui/cage_counter_view_model.gd")


func _check_onboarding_tutorial_ui_flow(app: Control) -> bool:
	var profile: ProfileInventory = app.get("profile_inventory")
	var save_service: SaveService = app.get("save_service")
	if profile == null or save_service == null:
		push_error("Tutorial UI test could not access profile or save services.")
		return false
	var history_before := JSON.stringify(profile.run_history)
	if not bool(app.call("_fresh_profile_needs_tutorial")):
		push_error("Fresh profile was not eligible for automatic Lessons start.")
		return false
	app.call("_on_start_pressed")
	await process_frame
	var run_state: RunState = app.get("run_state")
	if run_state == null or not run_state.is_tutorial_run() or str(run_state.challenge_config.get("id", "")) != "tutorial_first_card":
		push_error("Lessons replay did not start the fixed tutorial challenge.")
		return false
	if str(run_state.current_environment.get("archetype_id", "")) != "motel_room" or run_state.bankroll != 80:
		push_error("Tutorial UI did not start with the authored First Night framing.")
		return false
	var coach_snapshot: Dictionary = app.get("coach_overlay").call("current_snapshot")
	if str(coach_snapshot.get("lesson_id", "")) != "tutorial_home_container" or not bool(coach_snapshot.get("gating", false)):
		push_error("Tutorial UI did not focus and gate the first Home beat.")
		return false
	if not bool(app.call("activate_interactable_object", "home_container:backpack_01")):
		push_error("Tutorial UI could not activate the highlighted Home backpack through the real object route.")
		return false
	await process_frame
	if not bool(app.get("run_inventory_screen").call("is_open")):
		push_error("Tutorial Home backpack did not open the shared inventory surface.")
		return false
	app.call("close_run_inventory")
	await process_frame
	coach_snapshot = app.get("coach_overlay").call("current_snapshot")
	if str(coach_snapshot.get("lesson_id", "")) != "tutorial_empty_loadout" or not bool(coach_snapshot.get("gating", false)):
		push_error("Tutorial did not advance from the backpack to the carried-inventory lesson.")
		return false
	app.call("open_run_menu")
	await process_frame
	var skip_button: Button = app.get("run_menu_skip_tutorial_button")
	if skip_button == null or not skip_button.visible or not _has_visible_text(app, "Skip Lessons"):
		push_error("Tutorial Run Menu did not expose Skip Lessons.")
		return false
	app.call("close_run_menu")
	var tutorial_lesson_ids: Array = []
	var library: ContentLibrary = app.get("library")
	for lesson_value in library.tutorial_lessons:
		if typeof(lesson_value) == TYPE_DICTIONARY and str((lesson_value as Dictionary).get("scope", "")) == "tutorial_run":
			tutorial_lesson_ids.append(str((lesson_value as Dictionary).get("id", "")))
	for lesson_id in tutorial_lesson_ids:
		if app.get("run_state") == null:
			app.call("start_tutorial_run")
			run_state = app.get("run_state")
		run_state.narrative_flags["tutorial_test_skip_beat"] = lesson_id
		if save_service.save_run(run_state, str(app.get("autosave_slot_id"))) != OK:
			push_error("Tutorial skip test could not seed a Resume Slot at %s." % lesson_id)
			return false
		app.call("_confirm_skip_tutorial")
		await process_frame
		if app.get("run_state") != null or save_service.has_run(str(app.get("autosave_slot_id"))):
			push_error("Tutorial skip left resumable run residue at %s." % lesson_id)
			return false
		if JSON.stringify(profile.run_history) != history_before:
			push_error("Tutorial skip changed profile run statistics at %s." % lesson_id)
			return false
		if lesson_id != tutorial_lesson_ids.back():
			app.call("start_tutorial_run")
			run_state = app.get("run_state")
	if not profile.tutorial_completed:
		push_error("Skipping Lessons did not persist onboarding completion.")
		return false
	app.call("start_tutorial_run")
	await process_frame
	if app.get("run_state") == null or not (app.get("run_state") as RunState).is_tutorial_run():
		push_error("Completed profile could not replay Lessons from the main menu.")
		return false
	profile.tutorial_completed = false
	run_state = app.get("run_state")
	run_state.run_status = RunState.RUN_STATUS_ENDED
	run_state.narrative_flags["demo_victory"] = true
	run_state.narrative_flags["demo_victory_route"] = RunState.GRAND_CASINO_HIGH_ROLLER_EVENT_ID
	run_state.narrative_flags["grand_casino_players_card_tier"] = RunState.GRAND_CASINO_PLAYERS_CARD_TIER_GOLD
	app.call("_process_terminal_meta_bag_drops")
	var meta_service: MetaCollectionService = app.get("meta_collection_service")
	var starter_id := 0
	for instance_value in meta_service.owned_instances():
		if typeof(instance_value) != TYPE_DICTIONARY:
			continue
		var instance: Dictionary = instance_value
		var stamp: Dictionary = instance.get("instance_data", {}) if typeof(instance.get("instance_data", {})) == TYPE_DICTIONARY else {}
		if bool(stamp.get("starter_card", false)):
			starter_id = int(instance.get("instance_id", 0))
			break
	if not profile.tutorial_completed or starter_id <= 0:
		push_error("Tutorial victory did not complete the profile and mint a starter card through the UI terminal route.")
		return false
	app.call("_on_run_report_home_requested")
	await process_frame
	await process_frame
	coach_snapshot = app.get("coach_overlay").call("current_snapshot")
	if str(coach_snapshot.get("lesson_id", "")) != "tip_starter_card_home" or not str(coach_snapshot.get("copy", "")).contains("recognition") or not str(coach_snapshot.get("copy", "")).contains("gone forever"):
		push_error("Tutorial victory did not fire the starter-card fragility handoff back home.")
		return false
	app.call("return_to_main_menu")
	await process_frame
	app.call("_on_start_pressed")
	await process_frame
	run_state = app.get("run_state")
	coach_snapshot = app.get("coach_overlay").call("current_snapshot")
	if run_state == null or run_state.is_tutorial_run() or not bool(run_state.challenge_modifiers().get("grand_casino_prestige", false)) or str(coach_snapshot.get("lesson_id", "")) == "tip_starter_card_home":
		push_error("First normal run after the tutorial did not carry prestige or repeated the starter-card tip.")
		return false
	app.set("run_state", null)
	app.call("return_to_main_menu")
	await process_frame
	meta_service.remove_instance(starter_id)
	meta_service.save()
	app.call("start_tutorial_run")
	await process_frame
	profile.tutorial_completed = false
	run_state = app.get("run_state")
	run_state.fail_run(RunState.FAILURE_BANKROLL_ZERO, "The tutorial bankroll ran out.")
	app.call("_route_failed_run_if_needed")
	app.call("_refresh")
	await process_frame
	var report_screen: RunReportScreen = app.get("run_report_screen")
	if profile.tutorial_completed or report_screen == null or report_screen.new_run_button.text != "Replay Lessons" or report_screen.home_button.text != "Start Normal Run" or not str(report_screen.outcome_how.text).contains("Replay the lesson"):
		push_error("Tutorial failure did not preserve incomplete state and offer replay or normal-start encouragement.")
		return false
	app.call("_on_run_report_new_run_requested")
	await process_frame
	run_state = app.get("run_state")
	if run_state == null or not run_state.is_tutorial_run() or profile.tutorial_completed:
		push_error("Tutorial failure replay did not restart First Night without completing onboarding.")
		return false
	run_state.fail_run(RunState.FAILURE_BANKROLL_ZERO, "The tutorial bankroll ran out again.")
	app.call("_route_failed_run_if_needed")
	app.call("_refresh")
	await process_frame
	app.call("_on_run_report_home_requested")
	await process_frame
	run_state = app.get("run_state")
	if run_state == null or run_state.is_tutorial_run() or not profile.tutorial_completed:
		push_error("Declining tutorial replay did not persist completion and start a normal run.")
		return false
	app.set("run_state", null)
	app.call("return_to_main_menu")
	return true

func _check_in_run_menu_flow(app: Control, save_service: SaveService, viewport_rect: Rect2) -> bool:
	if save_service == null:
		push_error("Run menu flow test could not access SaveService.")
		return false
	var menu_slot := "foundation_ui_run_menu_slot"
	var remove_error := _remove_save_slot(save_service, menu_slot)
	if remove_error != OK:
		push_error("Could not prepare the run-menu test save slot.")
		return false
	app.set("autosave_slot_id", menu_slot)

	app.call("start_foundation_run", "UI-RUN-MENU-SCREENS", RunStateScript.custom_challenge("ui_run_menu_home_fixture", "UI-RUN-MENU-SCREENS", {"home_archetype_id": "bar"}))
	await process_frame
	var top_menu_button: Button = app.get("top_menu_button")
	if top_menu_button == null:
		push_error("Run HUD did not expose the Menu button.")
		return false
	var serialized_before_button_menu := JSON.stringify(app.call("serialized_run_state"))
	top_menu_button.emit_signal("pressed")
	await process_frame
	var button_menu_snapshot: Dictionary = app.call("current_run_menu_snapshot")
	if not bool(button_menu_snapshot.get("visible", false)):
		push_error("HUD Menu button did not open the in-run menu overlay.")
		return false
	if not _has_visible_text(app, "Resume") or not _has_visible_text(app, "Save") or not _has_visible_text(app, "Load") or not _has_visible_text(app, "Abandon Run"):
		push_error("In-run menu did not expose the required player-facing actions.")
		return false
	if not _has_visible_text(app, "Resume Slot") or not _has_visible_text(app, "Save overwrites"):
		push_error("In-run menu did not explain the single save-slot overwrite policy.")
		return false
	if not _control_fits_viewport(app.get("run_menu_panel"), viewport_rect, "run menu panel"):
		return false
	if serialized_before_button_menu != JSON.stringify(app.call("serialized_run_state")):
		push_error("Opening the in-run menu from the HUD mutated serialized RunState.")
		return false
	app.call("close_run_menu")
	await process_frame
	if bool(app.call("current_run_menu_snapshot").get("visible", true)):
		push_error("Resume did not close the in-run menu overlay.")
		return false
	if serialized_before_button_menu != JSON.stringify(app.call("serialized_run_state")):
		push_error("Resuming from the in-run menu mutated serialized RunState.")
		return false
	if not await _check_run_menu_open_resume(app, "ENVIRONMENT", "environment screen"):
		return false

	if not await _travel_to_first_game_environment(app):
		push_error("Run menu game screen test could not reach a gambling environment.")
		return false
	if not _enter_ui_test_game(app):
		push_error("Run menu game screen test did not find a game after reaching a gambling environment.")
		return false
	await process_frame
	if not await _check_run_menu_open_resume(app, "GAME", "game screen"):
		return false
	app.call("back_to_environment")
	await process_frame

	if not bool(app.call("select_action_category", "events")):
		push_error("Run menu screen test could not open the event category.")
		return false
	await process_frame
	if not await _check_run_menu_open_resume(app, "EVENT", "event screen"):
		return false
	if not bool(app.call("select_action_category", "travel")):
		push_error("Run menu screen test could not open the travel category.")
		return false
	await process_frame
	if not await _check_run_menu_open_resume(app, "TRAVEL", "travel screen"):
		return false
	app.call("_set_current_screen", "RESULT")
	app.call("_refresh")
	await process_frame
	if not await _check_run_menu_open_resume(app, "RESULT", "result screen"):
		return false

	app.call("start_foundation_run", "UI-RUN-MENU-FAILURE")
	await process_frame
	var failure_run: RunState = app.get("run_state")
	failure_run.fail_run(RunState.FAILURE_POLICE_CAPTURE, RunState.POLICE_CAPTURE_FAILURE_MESSAGE)
	app.call("_refresh")
	await process_frame
	if not await _check_run_menu_open_resume(app, "FAILURE", "failure screen"):
		return false

	app.call("start_foundation_run", "UI-RUN-MENU-VICTORY")
	await process_frame
	var victory_run: RunState = app.get("run_state")
	victory_run.narrative_flags["demo_victory"] = true
	victory_run.narrative_flags["demo_victory_route"] = "high_roller_cashout"
	victory_run.narrative_flags["demo_victory_message"] = RunState.GRAND_CASINO_HIGH_ROLLER_DEFAULT_SUCCESS_MESSAGE
	victory_run.narrative_flags["demo_finale_completed"] = true
	victory_run.run_status = RunState.RUN_STATUS_ENDED
	app.call("_refresh")
	await process_frame
	if not await _check_run_menu_open_resume(app, "VICTORY", "victory screen"):
		return false

	app.call("start_foundation_run", "UI-RUN-MENU-SAVE-ENV")
	await process_frame
	app.call("open_run_menu")
	await process_frame
	app.call("save_run_from_menu")
	await process_frame
	var env_saved_state: Dictionary = app.call("serialized_run_state")
	var env_saved_bankroll := int(env_saved_state.get("bankroll", 0))
	var env_saved_seed := str(env_saved_state.get("seed_text", ""))
	var env_run: RunState = app.get("run_state")
	env_run.bankroll += 77
	app.call("load_run_from_menu")
	await process_frame
	var env_loaded_state: Dictionary = app.call("serialized_run_state")
	if int(env_loaded_state.get("bankroll", 0)) != env_saved_bankroll or str(env_loaded_state.get("seed_text", "")) != env_saved_seed:
		push_error("In-run menu load did not restore the environment-screen save.")
		return false
	if str(app.call("current_screen_snapshot").get("screen", "")) != "ENVIRONMENT":
		push_error("Environment-screen in-run load did not return to a playable run view.")
		return false

	app.call("start_foundation_run", "UI-RUN-MENU-SAVE-GAME", RunStateScript.custom_challenge("ui_run_menu_save_game_fixture", "UI-RUN-MENU-SAVE-GAME", {"home_archetype_id": "bar"}))
	await process_frame
	if not await _travel_to_first_game_environment(app):
		push_error("Run menu game-surface save test could not reach a gambling environment.")
		return false
	if not _enter_ui_test_game(app):
		push_error("Run menu game-surface save test did not find a game after reaching a gambling environment.")
		return false
	await process_frame
	if str(app.call("current_screen_snapshot").get("screen", "")) != "GAME":
		push_error("Run menu game-surface save test could not enter a game.")
		return false
	app.call("open_run_menu")
	await process_frame
	app.call("save_run_from_menu")
	await process_frame
	var game_saved_state: Dictionary = app.call("serialized_run_state")
	var game_saved_bankroll := int(game_saved_state.get("bankroll", 0))
	var game_saved_seed := str(game_saved_state.get("seed_text", ""))
	var game_run: RunState = app.get("run_state")
	game_run.bankroll += 41
	app.call("load_run_from_menu")
	await process_frame
	var game_loaded_state: Dictionary = app.call("serialized_run_state")
	if int(game_loaded_state.get("bankroll", 0)) != game_saved_bankroll or str(game_loaded_state.get("seed_text", "")) != game_saved_seed:
		push_error("In-run menu load did not restore the game-surface save.")
		return false
	if str(app.call("current_screen_snapshot").get("screen", "")) == "START":
		push_error("Game-surface in-run load incorrectly returned to the main menu.")
		return false
	if not await _check_showdown_phase_ui(app):
		return false

	app.call("start_foundation_run", "UI-RUN-MENU-ABANDON")
	await process_frame
	app.call("open_run_menu")
	await process_frame
	app.call("abandon_run_from_menu")
	await process_frame
	var abandoned_run: RunState = app.get("run_state")
	if abandoned_run.run_status != RunState.RUN_STATUS_FAILED or abandoned_run.run_failure_reason != RunState.FAILURE_ABANDONED:
		push_error("Abandon Run did not set the abandoned terminal failure reason.")
		return false
	if str(app.call("current_screen_snapshot").get("screen", "")) != "FAILURE":
		push_error("Abandon Run did not route to the failure summary.")
		return false
	if bool(app.call("current_run_menu_snapshot").get("visible", true)):
		push_error("Abandon Run left the in-run menu visible over the terminal summary.")
		return false
	if not _has_visible_text(app, "Walked away"):
		push_error("Abandon Run did not present a clear terminal summary title.")
		return false
	if not await _check_run_menu_main_menu_button_closes_overlay(app, "UI-RUN-MENU-MAIN", false):
		return false
	if not await _check_run_menu_main_menu_button_closes_overlay(app, "UI-RUN-MENU-META", true):
		return false
	return true


func _check_showdown_phase_ui(app: Control) -> bool:
	var environment := _grand_casino_environment_for_ui(app)
	if environment.is_empty():
		push_error("Showdown phase UI fixture could not load the Grand Casino.")
		return false
	environment["event_ids"] = [RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID]
	var run_state := _grand_casino_fixture_run("UI-HOUSE-CALLS-PHASES", environment)
	run_state.current_environment["turns"] = 0
	var objective := _copy_dict(run_state.current_environment.get("demo_objective", {}))
	run_state.add_suspicion("ui_showdown_phase", int(objective.get("showdown_heat_threshold", 70)), "behavior")
	run_state.evaluate_environment_objective_state()
	_set_ui_fixture_run(app, run_state)
	app.call("_set_current_screen", "EVENT")
	app.call("_refresh")
	if not bool(app.call("_show_interactable_event_popup", RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID)):
		push_error("Showdown phase UI could not open Rourke's call.")
		return false
	var arrival_popup: Dictionary = app.call("current_event_choice_popup_snapshot")
	if not _popup_has_choice(arrival_popup, "enter_back_room"):
		push_error("Showdown phase UI did not present the back-room arrival.")
		return false
	app.call("resolve_event_choice", RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID, "enter_back_room")
	await process_frame
	var walk_popup: Dictionary = app.call("current_event_choice_popup_snapshot")
	if not bool(walk_popup.get("visible", false)) or not bool(walk_popup.get("blocking", false)) or bool(walk_popup.get("dismissible", true)) or not _popup_has_choice(walk_popup, "keep_everything"):
		push_error("Showdown walk did not auto-open as a blocking one-choice scene.")
		return false
	app.call("resolve_event_choice", RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID, "keep_everything")
	await process_frame
	var pat_down_popup: Dictionary = app.call("current_event_choice_popup_snapshot")
	if not _popup_has_choice(pat_down_popup, "face_rourke") or str(pat_down_popup.get("summary", "")).findn("Pat-down: Clean") == -1:
		push_error("Showdown pat-down tier was not visible before interrogation.")
		return false
	app.call("resolve_event_choice", RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID, "face_rourke")
	await process_frame
	var first_beat: Dictionary = app.call("current_event_choice_popup_snapshot")
	if str(first_beat.get("summary", "")).find("Beat 1/3") == -1 or str(first_beat.get("summary", "")).find("Stakes:") == -1 or not _popup_has_choice(first_beat, "hold_steady") or not _popup_has_choice(first_beat, "talk_down") or not _popup_has_choice(first_beat, "take_the_edge"):
		push_error("Showdown interrogation did not show real evidence, visible stakes, and three responses.")
		return false
	app.call("resolve_event_choice", RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID, "hold_steady")
	await process_frame
	var second_beat: Dictionary = app.call("current_event_choice_popup_snapshot")
	if str(second_beat.get("summary", "")).find("Beat 2/3") == -1:
		push_error("Showdown interrogation did not advance and auto-open beat two.")
		return false
	app.call("resolve_event_choice", RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID, "hold_steady")
	await process_frame
	var third_beat: Dictionary = app.call("current_event_choice_popup_snapshot")
	if str(third_beat.get("summary", "")).find("Beat 3/3") == -1:
		push_error("Showdown interrogation did not advance and auto-open beat three.")
		return false
	app.call("resolve_event_choice", RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID, "hold_steady")
	await process_frame
	var duel_run: RunState = app.get("run_state")
	var duel_snapshot: Dictionary = app.call("current_game_view_snapshot")
	var duel_surface := duel_snapshot
	if str(app.get("current_screen")) != "GAME" or duel_run == null or str(duel_run.current_environment.get("archetype_id", "")) != RunState.GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID:
		push_error("Final interrogation beat did not move the player into the Back Room game surface.")
		return false
	var closed_popup: Dictionary = app.call("current_event_choice_popup_snapshot")
	if not bool(duel_surface.get("boss_duel_active", false)) or str(duel_surface.get("dealer_name", "")) != "Rourke" or bool(closed_popup.get("visible", false)):
		push_error("Back Room transition did not expose Rourke's boss blackjack surface and close the event popup.")
		return false
	app.call("back_to_environment")
	if str(app.get("current_screen")) != "GAME":
		push_error("Rourke's active duel allowed the player to back out of the locked game surface.")
		return false
	return true


func _popup_has_choice(snapshot: Dictionary, choice_id: String) -> bool:
	for choice_value in _copy_array(snapshot.get("choices", [])):
		if typeof(choice_value) == TYPE_DICTIONARY and str((choice_value as Dictionary).get("id", "")) == choice_id:
			return true
	return false


func _check_run_menu_main_menu_button_closes_overlay(app: Control, seed: String, meta_session: bool) -> bool:
	if meta_session:
		app.call("return_to_main_menu")
		await process_frame
		app.call("open_meta_home")
	else:
		app.call("start_foundation_run", seed)
	await process_frame
	app.call("open_run_menu")
	await process_frame
	var menu_snapshot: Dictionary = app.call("current_run_menu_snapshot")
	if not bool(menu_snapshot.get("visible", false)):
		push_error("Run menu Main Menu regression could not open the overlay.")
		return false
	var main_menu_button: Button = app.get("run_menu_main_menu_button")
	if main_menu_button == null or main_menu_button.disabled:
		push_error("Run menu Main Menu regression could not press the button.")
		return false
	main_menu_button.emit_signal("pressed")
	await process_frame
	var after_snapshot: Dictionary = app.call("current_run_menu_snapshot")
	if bool(after_snapshot.get("visible", true)):
		push_error("Run menu Main Menu button left the overlay visible after one press%s." % (" in meta home" if meta_session else ""))
		return false
	if str(app.call("current_screen_snapshot").get("screen", "")) != "START":
		push_error("Run menu Main Menu button did not return to the start screen%s." % (" from meta home" if meta_session else ""))
		return false
	return true


func _check_run_menu_open_resume(app: Control, expected_screen: String, label: String) -> bool:
	var screen_before := str(app.call("current_screen_snapshot").get("screen", ""))
	if screen_before != expected_screen:
		push_error("Run menu %s expected screen %s before open but saw %s." % [label, expected_screen, screen_before])
		return false
	var serialized_before := JSON.stringify(app.call("serialized_run_state"))
	app.call("open_run_menu")
	await process_frame
	var open_snapshot: Dictionary = app.call("current_run_menu_snapshot")
	if not bool(open_snapshot.get("visible", false)):
		push_error("Run menu did not open from %s." % label)
		return false
	if str(open_snapshot.get("screen", "")) != expected_screen:
		push_error("Run menu snapshot did not preserve %s while open." % label)
		return false
	if serialized_before != JSON.stringify(app.call("serialized_run_state")):
		push_error("Run menu open mutated serialized RunState from %s." % label)
		return false
	app.call("close_run_menu")
	await process_frame
	var close_snapshot: Dictionary = app.call("current_run_menu_snapshot")
	if bool(close_snapshot.get("visible", true)):
		push_error("Run menu resume did not close from %s." % label)
		return false
	if str(app.call("current_screen_snapshot").get("screen", "")) != expected_screen:
		push_error("Run menu resume did not return to %s." % label)
		return false
	if serialized_before != JSON.stringify(app.call("serialized_run_state")):
		push_error("Run menu resume mutated serialized RunState from %s." % label)
		return false
	return true


func _travel_to_first_game_environment(app: Control) -> bool:
	return await _travel_to_first_game_environment_depth(app, 0, {})


func _travel_to_first_game_environment_depth(app: Control, depth: int, visited_targets: Dictionary) -> bool:
	var current_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var current_game_ids_value: Variant = current_snapshot.get("game_ids", [])
	var current_game_ids: Array = []
	if typeof(current_game_ids_value) == TYPE_ARRAY:
		current_game_ids = current_game_ids_value
	if not current_game_ids.is_empty():
		return true
	if depth >= 3:
		return false
	var travel_choices_value: Variant = current_snapshot.get("travel_choices", [])
	var travel_choices: Array = []
	if typeof(travel_choices_value) == TYPE_ARRAY:
		travel_choices = travel_choices_value
	for preferred_game_id in ["bar_dice", "blackjack", "video_poker", "pull_tabs"]:
		for choice_value in travel_choices:
			if typeof(choice_value) != TYPE_DICTIONARY:
				continue
			var preferred_choice: Dictionary = choice_value
			var preferred_target_id := str(preferred_choice.get("id", ""))
			if preferred_target_id.is_empty() or not _archetype_has_game(app, preferred_target_id, preferred_game_id):
				continue
			if await _travel_to_target_and_check_games(app, preferred_target_id):
				return true
	for choice_value in travel_choices:
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = choice_value
		var target_id := str(choice.get("id", ""))
		if target_id.is_empty() or not _archetype_has_games(app, target_id):
			continue
		if await _travel_to_target_and_check_games(app, target_id):
			return true
	for choice_value in travel_choices:
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var waypoint_choice: Dictionary = choice_value
		var waypoint_id := str(waypoint_choice.get("id", ""))
		if waypoint_id.is_empty() or bool(visited_targets.get(waypoint_id, false)):
			continue
		visited_targets[waypoint_id] = true
		if not bool(app.call("select_travel_option", waypoint_id)):
			continue
		app.call("confirm_selected_travel")
		await process_frame
		if await _travel_to_first_game_environment_depth(app, depth + 1, visited_targets):
			return true
		return false
	return false


func _travel_to_target_and_check_games(app: Control, target_id: String) -> bool:
	if not bool(app.call("select_travel_option", target_id)):
		return false
	await process_frame
	app.call("confirm_selected_travel")
	await process_frame
	app.call("select_action_category", "games")
	await process_frame
	var traveled_snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var traveled_game_ids_value: Variant = traveled_snapshot.get("game_ids", [])
	var traveled_game_ids: Array = []
	if typeof(traveled_game_ids_value) == TYPE_ARRAY:
		traveled_game_ids = traveled_game_ids_value
	return not traveled_game_ids.is_empty()


func _check_pull_tab_buy_button_single_activation(app: Control) -> bool:
	var original_run_state: Variant = app.get("run_state")
	var original_dev_game_test_mode := bool(app.get("dev_game_test_mode"))
	app.call("start_game_test_session", "pull_tabs")
	await process_frame
	await process_frame
	var run_state: RunState = app.get("run_state")
	var canvas: Control = app.get("game_surface_canvas")
	if run_state == null or app.get("current_game") == null or canvas == null:
		push_error("Pull-tab duplicate-input fixture could not start the pull-tab surface.")
		return false
	run_state.bankroll = 100000
	app.call("_refresh")
	await process_frame
	var before_snapshot: Dictionary = app.call("current_game_view_snapshot")
	if str(before_snapshot.get("surface_renderer", "")) != "pull_tab_machine":
		push_error("Pull-tab duplicate-input fixture did not render the pull-tab machine.")
		return false
	var deals_value: Variant = before_snapshot.get("pull_tab_deals", [])
	var deals: Array = deals_value if typeof(deals_value) == TYPE_ARRAY else []
	if deals.is_empty() or typeof(deals[0]) != TYPE_DICTIONARY:
		push_error("Pull-tab duplicate-input fixture did not expose a purchasable deal.")
		return false
	var first_deal: Dictionary = deals[0]
	var ticket_price := maxi(1, int(first_deal.get("price", 1)))
	var tray_before := int(before_snapshot.get("pull_tab_tray_count", 0))
	var bankroll_before := run_state.bankroll
	var click_position: Vector2 = canvas.call("local_position_for_surface_action", "pull_tab_buy", 0)
	if click_position.x < 0.0 or click_position.y < 0.0:
		push_error("Pull-tab duplicate-input fixture could not locate the buy button hit region.")
		return false
	var touch_event := InputEventScreenTouch.new()
	touch_event.pressed = true
	touch_event.position = click_position
	canvas.call("_gui_input", touch_event)
	canvas.set("last_touch_press_msec", Time.get_ticks_msec() - 500)
	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	mouse_event.pressed = true
	mouse_event.position = click_position
	canvas.call("_gui_input", mouse_event)
	await process_frame
	var after_snapshot: Dictionary = app.call("current_game_view_snapshot")
	var tray_after := int(after_snapshot.get("pull_tab_tray_count", 0))
	if tray_after != tray_before + 1:
		push_error("One pull-tab input activated %d purchases instead of 1." % (tray_after - tray_before))
		return false
	if run_state.bankroll != bankroll_before - ticket_price:
		push_error("One pull-tab input charged $%d instead of one $%d ticket." % [bankroll_before - run_state.bankroll, ticket_price])
		return false
	app.call("return_to_main_menu")
	await process_frame
	app.set("run_state", original_run_state)
	app.set("dev_game_test_mode", original_dev_game_test_mode)
	app.call("_refresh_run_action_service")
	app.call("_refresh_start_screen")
	await process_frame
	return true


func _check_slot_autoplay_button_one_click(app: Control) -> bool:
	var original_run_state: Variant = app.get("run_state")
	var original_dev_game_test_mode := bool(app.get("dev_game_test_mode"))
	app.call("start_game_test_session", "slot")
	await process_frame
	await process_frame
	var run_state: RunState = app.get("run_state")
	var canvas: Control = app.get("game_surface_canvas")
	if run_state == null or app.get("current_game") == null or canvas == null:
		push_error("Slot autoplay one-click fixture could not start the slot surface.")
		return false
	run_state.bankroll = 100000
	app.call("_refresh")
	await process_frame
	var before_snapshot: Dictionary = app.call("current_game_view_snapshot")
	if bool(before_snapshot.get("slot_autoplay_active", false)):
		push_error("Slot autoplay one-click fixture started with autoplay already active.")
		return false
	var click_position: Vector2 = canvas.call("local_position_for_surface_action", "slot_auto_toggle", 0)
	if click_position.x < 0.0 or click_position.y < 0.0:
		push_error("Slot autoplay one-click fixture could not locate the AUTO hit region.")
		return false
	var machine_before: Dictionary = SlotMachineStateScript.read_machine(run_state.current_environment, "slot")
	var spin_count_before := int(machine_before.get("spin_count", 0))
	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	mouse_event.pressed = true
	mouse_event.position = click_position
	canvas.call("_gui_input", mouse_event)
	var machine_after_click: Dictionary = SlotMachineStateScript.read_machine(run_state.current_environment, "slot")
	if not bool(machine_after_click.get("slot_autoplay_active", false)):
		push_error("Clicking the slot AUTO button did not activate autoplay on the first click.")
		return false
	if int(machine_after_click.get("slot_autoplay_next_msec", 0)) <= 0:
		push_error("Clicking the slot AUTO button did not schedule the first autoplay spin.")
		return false
	var after_click_snapshot: Dictionary = app.call("current_game_view_snapshot")
	if not bool(after_click_snapshot.get("slot_autoplay_active", false)):
		push_error("Slot surface did not show AUTO ON immediately after the first click.")
		return false
	await process_frame
	var machine_after_frame: Dictionary = SlotMachineStateScript.read_machine(run_state.current_environment, "slot")
	if int(machine_after_frame.get("spin_count", 0)) != spin_count_before:
		push_error("Slot autoplay fired an immediate spin on the same frame as the AUTO click.")
		return false
	app.call("return_to_main_menu")
	await process_frame
	app.set("run_state", original_run_state)
	app.set("dev_game_test_mode", original_dev_game_test_mode)
	app.call("_refresh_run_action_service")
	app.call("_refresh_start_screen")
	await process_frame
	return true


func _check_all_in_wager_confirmation_recovery(app: Control) -> bool:
	var original_run_state: Variant = app.get("run_state")
	var original_dev_game_test_mode := bool(app.get("dev_game_test_mode"))
	app.call("start_game_test_session", "slot")
	await process_frame
	await process_frame
	var run_state: RunState = app.get("run_state")
	if run_state == null or app.get("current_game") == null:
		push_error("All-in confirmation fixture could not start the slot test session.")
		return false
	run_state.bankroll = 2
	app.call("_refresh")
	await process_frame
	if not bool(app.call("_handle_module_surface_action", "select_bet_option:bet_2", 0, true)):
		push_error("All-in confirmation fixture could not select the minimum slot bet.")
		return false
	if not bool(app.call("_handle_module_surface_action", "slot_auto_toggle", 0, false)):
		push_error("All-in confirmation fixture could not enable slot autoplay.")
		return false
	var autoplay_machine: Dictionary = SlotMachineStateScript.read_machine(run_state.current_environment, "slot")
	autoplay_machine["slot_autoplay_next_msec"] = 1
	SlotMachineStateScript.write_machine(run_state.current_environment, "slot", autoplay_machine)
	for _index in range(5):
		await process_frame
	var popup: Dictionary = app.call("current_event_choice_popup_snapshot")
	if not bool(popup.get("visible", false)) or str(popup.get("popup_type", "")) != "wager_confirmation":
		push_error("All-in slot autoplay did not open the wager confirmation popup.")
		return false
	if int(run_state.bankroll) != 2:
		push_error("All-in confirmation mutated bankroll before the player confirmed the wager.")
		return false
	var game_snapshot: Dictionary = app.call("current_game_view_snapshot")
	if bool(game_snapshot.get("slot_autoplay_active", false)):
		push_error("All-in confirmation did not pause slot autoplay while waiting for the player.")
		return false
	app.call("cancel_pending_wager_confirmation")
	for _index in range(5):
		await process_frame
	popup = app.call("current_event_choice_popup_snapshot")
	if bool(popup.get("visible", false)) or bool(popup.get("blocking", false)):
		push_error("Canceling the all-in confirmation left the blocking popup active.")
		return false
	game_snapshot = app.call("current_game_view_snapshot")
	if bool(game_snapshot.get("slot_autoplay_active", false)):
		push_error("Canceling the all-in confirmation restarted slot autoplay and re-trapped the run.")
		return false
	if int(run_state.bankroll) != 2:
		push_error("Canceling the all-in confirmation changed bankroll.")
		return false
	run_state.add_item("coin_return_shim")
	var refund_machine: Dictionary = SlotMachineStateScript.read_machine(run_state.current_environment, "slot")
	refund_machine["format_id"] = "classic_3_reel"
	SlotMachineStateScript.write_machine(run_state.current_environment, "slot", refund_machine)
	var slot_game: GameModule = app.get("current_game")
	var wager_cost := slot_game.wager_cost_for_context("spin", 0, run_state, run_state.current_environment, {})
	var guaranteed_return := slot_game.minimum_wager_return_for_context("spin", 0, wager_cost, run_state, run_state.current_environment, {})
	if wager_cost != 2 or guaranteed_return != 1:
		push_error("Coin-Return Shim fixture did not report its guaranteed $1 return on a $2 three-reel spin.")
		return false
	if bool(app.call("_wager_needs_final_bankroll_confirmation", slot_game, "spin", 0, wager_cost, {})):
		push_error("A guaranteed Coin-Return Shim refund still classified the slot spin as run-ending.")
		return false
	var refunded_spin_count_before := int(refund_machine.get("spin_count", 0))
	app.call("_resolve_game_action", "spin", true, false, false)
	await process_frame
	popup = app.call("current_event_choice_popup_snapshot")
	if bool(popup.get("visible", false)) and str(popup.get("popup_type", "")) == "wager_confirmation":
		push_error("Coin-Return Shim's guaranteed survival still opened the all-in confirmation popup.")
		return false
	var refund_machine_after: Dictionary = SlotMachineStateScript.read_machine(run_state.current_environment, "slot")
	if int(refund_machine_after.get("spin_count", 0)) != refunded_spin_count_before + 1:
		push_error("The guaranteed-refund slot spin did not execute after skipping confirmation.")
		return false
	if not run_state.has_liquid_run_funds():
		push_error("Coin-Return Shim did not preserve spendable funds after the all-in slot spin.")
		return false
	if run_state.grand_casino_game_uses_chips("slot", run_state.current_environment) and run_state.grand_casino_chips <= 0:
		push_error("Grand Casino Coin-Return Shim refund did not return as a redeemable chip.")
		return false
	app.call("return_to_main_menu")
	await process_frame
	app.set("run_state", original_run_state)
	app.set("dev_game_test_mode", original_dev_game_test_mode)
	app.call("_refresh_run_action_service")
	app.call("_refresh_start_screen")
	await process_frame
	return true


func _check_confirmed_all_in_wager_result_then_failure(app: Control) -> bool:
	var original_run_state: Variant = app.get("run_state")
	var original_dev_game_test_mode := bool(app.get("dev_game_test_mode"))
	app.call("start_foundation_run", "UI-ALL-IN-RESULT")
	await process_frame
	var run_state: RunState = app.get("run_state")
	if run_state == null:
		push_error("Confirmed all-in fixture could not start a foundation run.")
		return false
	run_state.bankroll = 2
	var environment := run_state.current_environment.duplicate(true)
	environment["economic_profile"] = {
		"stake_floor": 1,
		"stake_ceiling": 2,
	}
	run_state.current_environment = environment
	app.set("current_game", AllInLosingFixtureGame.new())
	app.set("selected_stake", 2)
	app.call("_set_current_screen", "GAME")
	app.call("_refresh")
	await process_frame
	app.call("_resolve_game_action", "all_in_loss", false, false, false)
	await process_frame
	var popup: Dictionary = app.call("current_event_choice_popup_snapshot")
	if not bool(popup.get("visible", false)) or str(popup.get("popup_type", "")) != "wager_confirmation":
		push_error("Confirmed all-in fixture did not open the wager confirmation popup.")
		return false
	if int(run_state.bankroll) != 2:
		push_error("Confirmed all-in fixture changed bankroll before confirmation.")
		return false
	app.call("confirm_pending_wager_action")
	await process_frame
	await process_frame
	var screen_snapshot: Dictionary = app.call("current_screen_snapshot")
	if str(screen_snapshot.get("screen", "")) == "FAILURE":
		push_error("Confirmed losing all-in routed to failure before showing the wager result.")
		return false
	if run_state.run_status != RunState.RUN_STATUS_ACTIVE:
		push_error("Confirmed losing all-in marked the run terminal before the result was acknowledged.")
		return false
	if int(run_state.bankroll) != 0:
		push_error("Confirmed losing all-in did not finish applying the wager result.")
		return false
	var game_snapshot: Dictionary = app.call("current_game_view_snapshot")
	if str(game_snapshot.get("result_message", "")).find("Fixture all-in wager lost") == -1:
		push_error("Confirmed losing all-in did not keep the resolved wager message visible.")
		return false
	if int(game_snapshot.get("result_stake", 0)) != 2 or int(game_snapshot.get("bankroll_delta", 0)) != -2 or bool(game_snapshot.get("won", true)):
		push_error("Confirmed losing all-in result did not report the settled stake, loss, and non-win.")
		return false
	app.call("back_to_environment")
	await process_frame
	screen_snapshot = app.call("current_screen_snapshot")
	if str(screen_snapshot.get("screen", "")) != "FAILURE" or run_state.run_status != RunState.RUN_STATUS_FAILED:
		push_error("Acknowledging a resolved losing all-in did not end the run.")
		return false
	var failure_summary: Dictionary = app.call("current_run_report_snapshot")
	var outcome: Dictionary = failure_summary.get("outcome", {})
	if str(outcome.get("key", "")) != RunState.FAILURE_BANKROLL_ZERO:
		push_error("Resolved losing all-in did not fail for bankroll zero.")
		return false
	if str(outcome.get("how", "")).is_empty():
		push_error("Resolved losing all-in run report lost its ending explanation.")
		return false
	app.call("return_to_main_menu")
	await process_frame
	app.set("run_state", original_run_state)
	app.set("dev_game_test_mode", original_dev_game_test_mode)
	app.call("_refresh_run_action_service")
	app.call("_refresh_start_screen")
	await process_frame
	return true


func _check_presented_bankroll_waits_for_result_reveal(app: Control) -> bool:
	var original_run_state: Variant = app.get("run_state")
	var original_dev_game_test_mode := bool(app.get("dev_game_test_mode"))
	app.call("start_foundation_run", "UI-BANKROLL-PRESENTATION")
	await process_frame
	var run_state: RunState = app.get("run_state")
	if run_state == null:
		push_error("Bankroll presentation fixture could not start a run.")
		return false
	run_state.bankroll = 100
	var fixture_game := BankrollPresentationFixtureGame.new()
	var environment := run_state.current_environment.duplicate(true)
	environment["game_ids"] = [fixture_game.get_id()]
	environment["game_states"] = {}
	environment["economic_profile"] = {"stake_floor": 10, "stake_ceiling": 100}
	run_state.set_environment(environment)
	app.call("_refresh_run_action_service")
	app.set("current_game", fixture_game)
	app.call("_reset_game_surface_runtime_state")
	app.call("_set_current_screen", "GAME")
	app.call("_clear_selected_game_action")
	app.call("_clear_selected_stake")
	if not bool(app.call("set_selected_stake", 10)):
		push_error("Bankroll presentation fixture could not select its stake.")
		return false
	var before_bankroll := int((app.call("serialized_run_state") as Dictionary).get("bankroll", -1))
	if before_bankroll != 100:
		push_error("Bankroll presentation fixture started from an unexpected bankroll: %d." % before_bankroll)
		return false
	app.call("_resolve_game_action", "bankroll_fixture_win", false, false, false)
	await process_frame
	var settled_bankroll := int((app.call("serialized_run_state") as Dictionary).get("bankroll", -1))
	var expected_presented := 90
	if settled_bankroll != 140:
		var debug_game_value: Variant = app.get("current_game")
		var debug_popup: Dictionary = app.call("current_event_choice_popup_snapshot")
		push_error("Bankroll presentation fixture did not settle simulation immediately: %d game=%s stake=%d screen=%s popup=%s." % [
			settled_bankroll,
			str(debug_game_value),
			int(app.get("selected_stake")),
			str((app.call("current_screen_snapshot") as Dictionary).get("screen", "")),
			JSON.stringify(debug_popup),
		])
		return false
	var mid_hud: Dictionary = app.call("current_objective_hud_snapshot")
	var mid_game: Dictionary = app.call("current_game_view_snapshot")
	var mid_save: Dictionary = app.call("save_status_snapshot")
	var mid_consequence: Dictionary = app.call("current_consequence_view_snapshot")
	if int(mid_hud.get("bankroll", -1)) != expected_presented:
		var debug_canvas := app.get("game_surface_canvas") as Control
		var debug_surface: Dictionary = debug_canvas.call("surface_runtime_status") if debug_canvas != null else {}
		push_error("Top HUD spoiled the settled bankroll during result animation: hud=%d hold=%s presented=%d surface=%s." % [
			int(mid_hud.get("bankroll", -1)),
			str(app.get("presented_bankroll_hold_active")),
			int(app.get("presented_bankroll_value")),
			JSON.stringify(debug_surface),
		])
		return false
	if int(mid_game.get("bankroll", -1)) != expected_presented:
		push_error("Game snapshot spoiled the settled bankroll during result animation.")
		return false
	if int(mid_save.get("visible_bankroll", -1)) != expected_presented:
		push_error("Save/status side channel spoiled the settled bankroll during result animation.")
		return false
	if int(mid_consequence.get("bankroll", -1)) != expected_presented or int(mid_consequence.get("recent_bankroll_delta", 999)) != 0:
		push_error("Consequence side channel exposed result money before the reveal boundary.")
		return false
	if int(mid_game.get("stake_max", 999)) > expected_presented:
		push_error("Stake availability used settled bankroll while result presentation was still active.")
		return false
	var game_surface_canvas := app.get("game_surface_canvas") as Control
	if game_surface_canvas == null:
		push_error("Bankroll presentation fixture could not inspect the game surface canvas.")
		return false
	var mid_surface: Dictionary = game_surface_canvas.call("surface_runtime_status")
	var mid_animations: Dictionary = mid_surface.get("surface_animations", {}) if typeof(mid_surface.get("surface_animations", {})) == TYPE_DICTIONARY else {}
	var reveal_animation: Dictionary = mid_animations.get(BankrollPresentationFixtureGame.PRESENTATION_CHANNEL, {}) if typeof(mid_animations.get(BankrollPresentationFixtureGame.PRESENTATION_CHANNEL, {})) == TYPE_DICTIONARY else {}
	if not bool(reveal_animation.get("active", false)):
		push_error("Bankroll presentation fixture did not expose an active reveal animation.")
		return false
	await create_timer(0.35).timeout
	await process_frame
	var post_hud: Dictionary = app.call("current_objective_hud_snapshot")
	var post_consequence: Dictionary = app.call("current_consequence_view_snapshot")
	if int(post_hud.get("bankroll", -1)) != settled_bankroll:
		push_error("Presented bankroll did not sync after the reveal animation completed.")
		return false
	if int(post_consequence.get("recent_bankroll_delta", 0)) != 40:
		push_error("Result delta did not become visible after the reveal animation completed.")
		return false
	run_state.bankroll = 100
	environment["game_states"] = {}
	run_state.set_environment(environment)
	app.set("current_game", fixture_game)
	app.call("_reset_game_surface_runtime_state")
	app.call("_set_current_screen", "GAME")
	app.call("_clear_selected_game_action")
	app.call("_clear_selected_stake")
	app.call("set_selected_stake", 10)
	app.call("_resolve_game_action", "bankroll_fixture_win", false, false, false)
	await process_frame
	var second_settled_bankroll := int((app.call("serialized_run_state") as Dictionary).get("bankroll", -1))
	app.call("back_to_environment")
	await process_frame
	var leave_hud: Dictionary = app.call("current_objective_hud_snapshot")
	if int(leave_hud.get("bankroll", -1)) != second_settled_bankroll:
		push_error("Leaving mid-animation did not snap presented bankroll to actual.")
		return false
	app.call("return_to_main_menu")
	await process_frame
	app.set("run_state", original_run_state)
	app.set("dev_game_test_mode", original_dev_game_test_mode)
	app.call("_refresh_run_action_service")
	app.call("_refresh_start_screen")
	await process_frame
	return true


func _check_background_slot_autoplay_isolated_from_active_game(app: Control) -> bool:
	var original_run_state: Variant = app.get("run_state")
	var original_dev_game_test_mode := bool(app.get("dev_game_test_mode"))
	app.call("start_game_test_session", "bar_dice")
	await process_frame
	await process_frame
	var run_state: RunState = app.get("run_state")
	if run_state == null or app.get("current_game") == null:
		push_error("Background slot isolation fixture could not start bar dice.")
		return false
	if not _install_background_slot_autoplay(app, run_state, "bet_2", 1):
		return false
	var before_snapshot: Dictionary = app.call("current_game_view_snapshot")
	if str(before_snapshot.get("game_id", "")) != "bar_dice":
		push_error("Background slot isolation fixture did not keep bar dice in the foreground.")
		return false
	for _index in range(6):
		await process_frame
	var runtime_result_value: Variant = app.get("last_environment_runtime_result")
	var runtime_result: Dictionary = {}
	if typeof(runtime_result_value) == TYPE_DICTIONARY:
		runtime_result = runtime_result_value as Dictionary
	if runtime_result.is_empty() or str(runtime_result.get("game_id", runtime_result.get("source_id", ""))) != "slot":
		push_error("Background slot autoplay did not resolve through the environment runtime result channel.")
		return false
	var foreground_result_value: Variant = app.get("last_game_result")
	var foreground_result: Dictionary = {}
	if typeof(foreground_result_value) == TYPE_DICTIONARY:
		foreground_result = foreground_result_value as Dictionary
	if str(foreground_result.get("game_id", foreground_result.get("source_id", ""))) == "slot":
		push_error("Background slot autoplay overwrote the foreground game result.")
		return false
	var after_snapshot: Dictionary = app.call("current_game_view_snapshot")
	if str(after_snapshot.get("game_id", "")) != "bar_dice":
		push_error("Background slot autoplay changed the active game snapshot.")
		return false
	if str(after_snapshot.get("result_message", "")).find("Autoplay") != -1 or str(after_snapshot.get("summary_source", "")) == "slot":
		push_error("Background slot autoplay leaked its result text into the bar dice surface.")
		return false
	app.call("return_to_main_menu")
	await process_frame
	app.set("run_state", original_run_state)
	app.set("dev_game_test_mode", original_dev_game_test_mode)
	app.call("_refresh_run_action_service")
	app.call("_refresh_start_screen")
	await process_frame
	return true


func _check_background_slot_all_in_confirmation(app: Control) -> bool:
	var original_run_state: Variant = app.get("run_state")
	var original_dev_game_test_mode := bool(app.get("dev_game_test_mode"))
	app.call("start_game_test_session", "bar_dice")
	await process_frame
	await process_frame
	var run_state: RunState = app.get("run_state")
	if run_state == null or app.get("current_game") == null:
		push_error("Background slot all-in fixture could not start bar dice.")
		return false
	run_state.bankroll = 2
	if not _install_background_slot_autoplay(app, run_state, "bet_2", 1):
		return false
	for _index in range(6):
		await process_frame
	var popup: Dictionary = app.call("current_event_choice_popup_snapshot")
	if not bool(popup.get("visible", false)) or str(popup.get("popup_type", "")) != "wager_confirmation":
		push_error("Background slot all-in autoplay did not open the wager confirmation popup.")
		return false
	if str(popup.get("action_label", "")).find("Slot") == -1:
		push_error("Background slot all-in popup did not identify the source slot autoplay.")
		return false
	if int(run_state.bankroll) != 2:
		push_error("Background slot all-in confirmation mutated bankroll before confirmation.")
		return false
	var slot_machine: Dictionary = SlotMachineStateScript.read_machine(run_state.current_environment, "slot")
	if bool(slot_machine.get("slot_autoplay_active", false)):
		push_error("Background slot all-in confirmation did not pause slot autoplay.")
		return false
	var game_snapshot: Dictionary = app.call("current_game_view_snapshot")
	if str(game_snapshot.get("game_id", "")) != "bar_dice":
		push_error("Background slot all-in confirmation changed the active game.")
		return false
	app.call("cancel_pending_wager_confirmation")
	for _index in range(3):
		await process_frame
	popup = app.call("current_event_choice_popup_snapshot")
	if bool(popup.get("visible", false)) or bool(popup.get("blocking", false)):
		push_error("Canceling background slot all-in confirmation left the popup active.")
		return false
	app.call("return_to_main_menu")
	await process_frame
	app.set("run_state", original_run_state)
	app.set("dev_game_test_mode", original_dev_game_test_mode)
	app.call("_refresh_run_action_service")
	app.call("_refresh_start_screen")
	await process_frame
	return true


func _install_background_slot_autoplay(app: Control, run_state: RunState, bet_id: String, next_msec: int) -> bool:
	var slot_game_value: Variant = app.call("_game_module_for_id", "slot")
	if not slot_game_value is GameModule:
		push_error("Background slot fixture could not load the slot module.")
		return false
	var slot_game: GameModule = slot_game_value
	var environment := run_state.current_environment.duplicate(true)
	var game_ids: Array = []
	for game_id_value in environment.get("game_ids", []):
		var game_id := str(game_id_value)
		if not game_id.is_empty() and not game_ids.has(game_id):
			game_ids.append(game_id)
	if not game_ids.has("bar_dice"):
		game_ids.insert(0, "bar_dice")
	if not game_ids.has("slot"):
		game_ids.append("slot")
	environment["game_ids"] = game_ids
	var states_value: Variant = environment.get("game_states", {})
	var states: Dictionary = {}
	if typeof(states_value) == TYPE_DICTIONARY:
		states = states_value as Dictionary
	if not states.has("slot"):
		states["slot"] = slot_game.generate_environment_state(run_state, environment, run_state.create_rng("ui_background_slot_state"))
	environment["game_states"] = states
	run_state.set_environment(environment)
	var machine: Dictionary = SlotMachineStateScript.read_machine(run_state.current_environment, "slot")
	if machine.is_empty():
		push_error("Background slot fixture could not create slot machine state.")
		return false
	machine = SlotMachineStateScript.set_selected_bet(machine, bet_id)
	machine["slot_autoplay_active"] = true
	machine["slot_autoplay_next_msec"] = next_msec
	SlotMachineStateScript.write_machine(run_state.current_environment, "slot", machine)
	app.call("_refresh")
	return true


func _game_surface_action_binding(app: Control, kind: String) -> Dictionary:
	var fallback_action := "surface_legal" if kind == "legal" else "surface_cheat"
	var fallback := {"action": fallback_action, "index": 0}
	var snapshot: Dictionary = app.call("current_game_view_snapshot")
	var bindings_value: Variant = snapshot.get("surface_action_bindings", {})
	if typeof(bindings_value) == TYPE_DICTIONARY:
		var bindings: Dictionary = bindings_value
		var binding_value: Variant = bindings.get(kind, {})
		if typeof(binding_value) == TYPE_DICTIONARY:
			var binding: Dictionary = binding_value
			if not binding.is_empty():
				var action := str(binding.get("action", fallback_action))
				if action.is_empty():
					action = fallback_action
				return {
					"action": action,
					"index": int(binding.get("index", 0)),
				}
	return _native_game_surface_action_binding(app, kind, fallback)


func _native_game_surface_action_binding(app: Control, kind: String, fallback: Dictionary) -> Dictionary:
	var surface_canvas := app.get("game_surface_canvas") as Control
	if surface_canvas == null or not surface_canvas.visible or not surface_canvas.has_method("current_view_snapshot"):
		return fallback
	var surface_snapshot: Dictionary = surface_canvas.call("current_view_snapshot")
	var hit_actions_value: Variant = surface_snapshot.get("surface_hit_actions", [])
	var hit_actions: Array = []
	if typeof(hit_actions_value) == TYPE_ARRAY:
		hit_actions = hit_actions_value
	var preferred_actions := []
	if kind == "legal":
		preferred_actions = ["video_poker_draw", "video_poker_deal", "video_poker_collect", "bar_dice_roll", "slot_spin"]
	else:
		preferred_actions = ["video_poker_mark", "blackjack_peek", "bar_dice_load", "roulette_late_bet", "baccarat_palm"]
	for preferred_action in preferred_actions:
		var preferred_binding := _surface_hit_action_binding(hit_actions, str(preferred_action))
		if not preferred_binding.is_empty():
			return preferred_binding
	var fallback_binding := _surface_hit_action_binding(hit_actions, str(fallback.get("action", "")))
	if not fallback_binding.is_empty():
		return fallback_binding
	return fallback


func _enter_action_fixture_game(app: Control, game_id: String) -> bool:
	var run_state_value: Variant = app.get("run_state")
	if not run_state_value is RunState:
		return false
	var run_state: RunState = run_state_value
	var game_value: Variant = app.call("_game_module_for_id", game_id)
	if not game_value is GameModule:
		return false
	var game: GameModule = game_value
	var environment_value: Variant = app.call("_game_test_environment", game_id, game)
	if typeof(environment_value) != TYPE_DICTIONARY:
		return false
	var environment: Dictionary = environment_value as Dictionary
	if environment.is_empty():
		return false
	run_state.set_environment(environment)
	app.call("_refresh_run_action_service")
	app.call("_refresh")
	app.call("enter_game", game_id)
	var screen_snapshot: Dictionary = app.call("current_screen_snapshot")
	return str(screen_snapshot.get("screen", "")) == "GAME"


func _surface_hit_action_binding(hit_actions: Array, action: String) -> Dictionary:
	if action.is_empty():
		return {}
	for hit_value in hit_actions:
		if typeof(hit_value) != TYPE_DICTIONARY:
			continue
		var hit_data: Dictionary = hit_value
		if str(hit_data.get("action", "")) != action:
			continue
		return {
			"action": action,
			"index": int(hit_data.get("index", 0)),
		}
	return {}


func _normalize_json_numbers(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var normalized_dict := {}
			var source_dict: Dictionary = value as Dictionary
			for key in source_dict.keys():
				normalized_dict[key] = _normalize_json_numbers(source_dict.get(key))
			return normalized_dict
		TYPE_ARRAY:
			var normalized_array: Array = []
			var source_array: Array = value as Array
			for entry in source_array:
				normalized_array.append(_normalize_json_numbers(entry))
			return normalized_array
		TYPE_INT, TYPE_FLOAT:
			return float(value)
		_:
			return value


func _stable_json(value: Variant) -> String:
	return JSON.stringify(_sort_json_value(_normalize_json_numbers(value)))


func _sort_json_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var sorted_dict := {}
			var source_dict: Dictionary = value as Dictionary
			var keys := source_dict.keys()
			keys.sort()
			for key in keys:
				sorted_dict[str(key)] = _sort_json_value(source_dict.get(key))
			return sorted_dict
		TYPE_ARRAY:
			var sorted_array: Array = []
			var source_array: Array = value as Array
			for entry in source_array:
				sorted_array.append(_sort_json_value(entry))
			return sorted_array
		_:
			return value


func _enter_ui_test_game(app: Control) -> bool:
	var snapshot: Dictionary = app.call("current_environment_view_snapshot")
	var game_ids_value: Variant = snapshot.get("game_ids", [])
	var game_ids: Array = []
	if typeof(game_ids_value) == TYPE_ARRAY:
		game_ids = game_ids_value
	if game_ids.is_empty():
		app.call("enter_first_available_game")
		return false
	for preferred_id in ["bar_dice", "blackjack", "video_poker", "pull_tabs"]:
		if game_ids.has(preferred_id):
			app.call("enter_game", preferred_id)
			return true
	app.call("enter_first_available_game")
	return true


func _archetype_has_game(app: Control, archetype_id: String, game_id: String) -> bool:
	var content_library: ContentLibrary = app.get("library")
	if content_library == null:
		return false
	for archetype_value in content_library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype: Dictionary = archetype_value
		if str(archetype.get("id", "")) != archetype_id:
			continue
		var game_pool_value: Variant = archetype.get("game_pool", [])
		var game_pool: Array = []
		if typeof(game_pool_value) == TYPE_ARRAY:
			game_pool = game_pool_value
		return game_pool.has(game_id)
	return false


func _archetype_has_games(app: Control, archetype_id: String) -> bool:
	var content_library: ContentLibrary = app.get("library")
	if content_library == null:
		return false
	for archetype_value in content_library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype: Dictionary = archetype_value
		if str(archetype.get("id", "")) != archetype_id:
			continue
		var game_pool_value: Variant = archetype.get("game_pool", [])
		var game_pool: Array = []
		if typeof(game_pool_value) == TYPE_ARRAY:
			game_pool = game_pool_value
		return not game_pool.is_empty()
	return false


func _check_run_journal_flow(app: Control, save_service: SaveService, viewport_rect: Rect2) -> bool:
	if save_service == null:
		push_error("Run journal flow test could not access SaveService.")
		return false
	var journal_slot := "foundation_ui_run_journal_slot"
	var remove_error := _remove_save_slot(save_service, journal_slot)
	if remove_error != OK:
		push_error("Could not prepare the run-journal test save slot.")
		return false
	app.set("autosave_slot_id", journal_slot)
	app.call("start_foundation_run", "UI-RUN-JOURNAL")
	await process_frame
	var journal_run: RunState = app.get("run_state")
	_add_run_journal_fixture_entries(journal_run)
	app.call("_refresh")
	await process_frame

	app.call("open_run_menu")
	await process_frame
	var menu_snapshot: Dictionary = app.call("current_run_menu_snapshot")
	if bool(menu_snapshot.get("journal_disabled", true)) or not _has_visible_text(app, "Journal"):
		push_error("Run menu did not expose an enabled Journal action.")
		return false
	if not _click_visible_button(app, "Journal"):
		push_error("Run menu Journal button was not clickable.")
		return false
	await process_frame
	var serialized_before_open := JSON.stringify(app.call("serialized_run_state"))
	var journal_snapshot: Dictionary = app.call("current_run_journal_snapshot")
	if not bool(journal_snapshot.get("visible", false)) or not bool(journal_snapshot.get("read_only", false)):
		push_error("Run journal did not open as a read-only overlay.")
		return false
	if not _control_fits_viewport(app.get("run_journal_panel"), viewport_rect, "run journal panel"):
		return false
	if serialized_before_open != JSON.stringify(app.call("serialized_run_state")):
		push_error("Opening the run journal mutated serialized RunState.")
		return false
	var entries: Array = journal_snapshot.get("entries", [])
	if entries.size() < 12:
		push_error("Run journal did not expose the expected story entry count.")
		return false
	if not _journal_entry_matches(entries, 0, "Travel", "travel"):
		return false
	if not _journal_entry_matches(entries, 1, "Debt", "debt"):
		return false
	if not _journal_entry_matches(entries, 2, "Item Bought", "item"):
		return false
	if not _journal_entry_matches(entries, 5, "Event", "event"):
		return false
	if not _journal_entry_matches(entries, 6, "Notable Win", "game"):
		return false
	if not _journal_entry_matches(entries, 8, "Heat Spike", "heat"):
		return false
	if not _journal_has_title(entries, "High-Roller Review") or not _journal_has_title(entries, "Rourke's Attention") or not _journal_has_title(entries, "Back Room") or not _journal_has_title(entries, "Showdown Outcome"):
		push_error("Run journal did not include Grand Casino endgame entries.")
		return false
	for entry_index in range(entries.size()):
		var entry: Dictionary = entries[entry_index]
		if int(entry.get("index", 0)) != entry_index + 1:
			push_error("Run journal entries were not exposed in chronological order.")
			return false
	app.call("close_run_journal")
	await process_frame
	if bool(app.call("current_run_journal_snapshot").get("visible", true)):
		push_error("Run journal did not close.")
		return false
	if serialized_before_open != JSON.stringify(app.call("serialized_run_state")):
		push_error("Closing the run journal mutated serialized RunState.")
		return false
	app.call("close_run_menu")
	await process_frame

	app.call("open_run_menu")
	await process_frame
	app.call("save_run_from_menu")
	await process_frame
	var saved_entries: Array = (app.call("current_run_journal_snapshot") as Dictionary).get("entries", [])
	var saved_entries_json := _stable_json(saved_entries)
	journal_run = app.get("run_state")
	journal_run.story_log = []
	app.call("load_run_from_menu")
	await process_frame
	app.call("open_run_journal")
	await process_frame
	var loaded_journal_snapshot: Dictionary = app.call("current_run_journal_snapshot")
	var loaded_entries: Array = loaded_journal_snapshot.get("entries", [])
	var loaded_entries_json := _stable_json(loaded_entries)
	if loaded_entries_json != saved_entries_json:
		push_error("Run journal contents did not survive save/load. saved=%d loaded=%d saved_last=%s loaded_last=%s" % [
			saved_entries.size(),
			loaded_entries.size(),
			_stable_json(saved_entries[saved_entries.size() - 1]) if not saved_entries.is_empty() else "{}",
			_stable_json(loaded_entries[loaded_entries.size() - 1]) if not loaded_entries.is_empty() else "{}",
		])
		return false
	app.call("close_run_journal")
	await process_frame

	app.call("start_foundation_run", "UI-RUN-JOURNAL-TERMINAL")
	await process_frame
	var terminal_run: RunState = app.get("run_state")
	terminal_run.fail_run(RunState.FAILURE_POLICE_CAPTURE, RunState.POLICE_CAPTURE_FAILURE_MESSAGE)
	app.call("_refresh")
	await process_frame
	app.call("open_run_journal")
	await process_frame
	var terminal_snapshot: Dictionary = app.call("current_run_journal_snapshot")
	var terminal_entries: Array = terminal_snapshot.get("entries", [])
	if terminal_entries.is_empty() or str((terminal_entries[terminal_entries.size() - 1] as Dictionary).get("category", "")) != "terminal":
		push_error("Run journal did not derive a terminal result entry for a failed run.")
		return false
	app.call("close_run_journal")
	await process_frame
	return true


func _add_run_journal_fixture_entries(run_state: RunState) -> void:
	run_state.log_story({
		"type": "travel",
		"to_environment_name": "Corner Store",
		"to_archetype_id": "corner_store",
		"message": "Traveled to Corner Store.",
	})
	run_state.log_story({
		"type": "lender_hook",
		"lender_id": "fast_eddie",
		"debt_changes": [{"lender_id": "fast_eddie", "balance": 30}],
		"message": "Fast Eddie fronts a little cash.",
	})
	run_state.log_story({
		"type": "item_purchase",
		"item_id": "cheap_sunglasses",
		"item_name": "Cheap Sunglasses",
		"bankroll_delta": -12,
		"message": "Bought Cheap Sunglasses.",
	})
	run_state.log_story({
		"type": "item_sale",
		"item_id": "scratch_pad",
		"item_name": "Scratch Pad",
		"bankroll_delta": 4,
		"message": "Sold Scratch Pad.",
	})
	run_state.log_story({
		"type": "item_use",
		"item_id": "cheap_sunglasses",
		"inventory_remove": ["cheap_sunglasses"],
		"message": "Used Cheap Sunglasses.",
	})
	run_state.log_story({
		"type": "event",
		"event_id": "machine_jam",
		"message": "A jammed machine makes the floor pause.",
	})
	run_state.log_story({
		"type": "game_action",
		"game_id": "blackjack",
		"bankroll_delta": 120,
		"message": "Blackjack pays out hard.",
	})
	run_state.log_story({
		"type": "game_action",
		"game_id": "roulette",
		"bankroll_delta": -35,
		"message": "Roulette takes a bite.",
	})
	run_state.log_story({
		"type": "game_action",
		"game_id": "baccarat",
		"suspicion_delta": 12,
		"message": "A risky baccarat press spikes heat.",
	})
	run_state.log_story({
		"type": "grand_casino_high_roller_ready",
		"event_id": "high_roller_cashout",
		"bankroll": 520,
		"net_winnings": 260,
		"message": "The casino host is ready to issue the Players Card.",
	})
	run_state.log_story({
		"type": "grand_casino_heat_reroute",
		"event_id": "the_house_calls",
		"attention_sources": ["rourke_watch"],
		"heat": 72,
		"message": "Rourke calls you to the back room.",
	})
	run_state.log_story({
		"type": "grand_casino_showdown_arrival",
		"event_id": "the_house_calls",
		"attention_sources": ["rourke_watch"],
		"heat": 72,
		"message": "Rourke takes you to the back room.",
	})
	run_state.log_story({
		"type": "demo_finale_result",
		"event_id": "the_house_calls",
		"branch": "pit_boss_showdown",
		"ended": true,
		"message": "Rourke lets you walk with your winnings.",
	})


func _journal_entry_matches(entries: Array, index: int, title: String, category: String) -> bool:
	if index < 0 or index >= entries.size() or typeof(entries[index]) != TYPE_DICTIONARY:
		push_error("Run journal entry %d was missing." % index)
		return false
	var entry: Dictionary = entries[index]
	if str(entry.get("title", "")) != title or str(entry.get("category", "")) != category:
		push_error("Run journal entry %d expected %s/%s but saw %s/%s." % [
			index,
			title,
			category,
			str(entry.get("title", "")),
			str(entry.get("category", "")),
		])
		return false
	return true


func _journal_has_title(entries: Array, title: String) -> bool:
	for entry_value in entries:
		if typeof(entry_value) == TYPE_DICTIONARY and str((entry_value as Dictionary).get("title", "")) == title:
			return true
	return false


func _check_final_demo_objective_hud_matrix(app: Control) -> bool:
	var pre_grand_snapshot: Dictionary = app.call("current_objective_hud_snapshot")
	if not _assert_objective_state(pre_grand_snapshot, "pre-grand", "pre-Grand objective HUD"):
		return false
	var pre_grand_guidance: Dictionary = pre_grand_snapshot.get("guidance", {})
	var pre_grand_text := str(pre_grand_guidance.get("text", pre_grand_snapshot.get("goal", "")))
	if pre_grand_text.find("Grand Casino") == -1 or pre_grand_text.find("heat") == -1:
		push_error("Pre-Grand objective guidance should mention reaching the Grand Casino and managing heat.")
		return false

	var grand_environment := _grand_casino_environment_for_ui(app)
	if grand_environment.is_empty():
		push_error("Could not build Grand Casino HUD fixture environment.")
		return false
	var objective: Dictionary = grand_environment.get("demo_objective", {})
	var high_roller_target := int(objective.get("high_roller_target_bankroll", objective.get("target_bankroll", 0)))
	var high_roller_net := int(objective.get("high_roller_net_winnings", 75))
	var high_roller_min_games := int(objective.get("high_roller_min_grand_casino_games", 3))
	var showdown_heat_threshold := int(objective.get("showdown_heat_threshold", 70))

	var close_cashout_run := _grand_casino_fixture_run("UI-HUD-GRAND-CLOSE", grand_environment)
	_record_grand_casino_clean_games(close_cashout_run, maxi(0, high_roller_min_games - 1))
	close_cashout_run.bankroll = maxi(high_roller_target - 20, int(close_cashout_run.narrative_flags.get("grand_casino_entry_bankroll", 0)) + high_roller_net)
	close_cashout_run.evaluate_environment_objective_state()
	_set_ui_fixture_run(app, close_cashout_run)
	if not _check_grand_casino_spatial_ui(app):
		return false
	close_cashout_run.grand_casino_chips = 17
	var casino_status_hud: Dictionary = app.call("current_run_status_hud_snapshot")
	if str(casino_status_hud.get("bankroll_text", "")).find("[CHIPS] 17") == -1:
		push_error("Grand Casino HUD did not show chips alongside bankroll.")
		return false
	close_cashout_run.grand_casino_chips = 0
	var close_snapshot: Dictionary = app.call("current_objective_hud_snapshot")
	if not _assert_objective_state(close_snapshot, "grand-incomplete", "Grand Casino close cashout HUD"):
		return false
	if str(close_snapshot.get("goal", "")).find("Bronze ready") == -1 or str(((close_snapshot.get("guidance", {}) as Dictionary).get("text", ""))).find("Bronze is ready") == -1:
		push_error("Grand Casino sequential Players Card HUD did not direct a frozen Bronze claim to Linda.")
		return false
	if not _assert_next_objective(close_snapshot, "travel", "travel:grand_casino_cage", "Grand Casino Bronze-ready HUD"):
		return false

	var heat_close_run := _grand_casino_fixture_run("UI-HUD-GRAND-HEAT", grand_environment)
	heat_close_run.add_suspicion("ui_hud_heat_close", maxi(0, showdown_heat_threshold - 5), "behavior")
	heat_close_run.evaluate_environment_objective_state()
	_set_ui_fixture_run(app, heat_close_run)
	var heat_snapshot: Dictionary = app.call("current_objective_hud_snapshot")
	if not _assert_objective_state(heat_snapshot, "grand-incomplete", "Grand Casino heat pressure HUD"):
		return false
	if str(heat_snapshot.get("goal", "")).find("Rourke") == -1 or not bool((heat_snapshot.get("guidance", {}) as Dictionary).get("heat_pressure_close", false)):
		push_error("Grand Casino heat-pressure HUD did not present Rourke pressure guidance.")
		return false

	var high_roller_run := _grand_casino_fixture_run("UI-HUD-HIGH-ROLLER", grand_environment)
	high_roller_run.narrative_flags["grand_casino_players_card_awarded_tier"] = RunState.GRAND_CASINO_PLAYERS_CARD_TIER_SILVER
	high_roller_run.narrative_flags["grand_casino_players_card_tier"] = RunState.GRAND_CASINO_PLAYERS_CARD_TIER_SILVER
	high_roller_run.narrative_flags["grand_casino_players_card_highest_tier"] = RunState.GRAND_CASINO_PLAYERS_CARD_TIER_SILVER
	high_roller_run.narrative_flags["grand_casino_players_card_segment_start_games"] = 0
	high_roller_run.narrative_flags["grand_casino_players_card_segment_start_net_winnings"] = 0
	high_roller_run.narrative_flags["grand_casino_comp_drink_tokens"] = 1
	high_roller_run.narrative_flags["grand_casino_comp_suite_rests"] = 1
	_record_grand_casino_clean_games(high_roller_run, high_roller_min_games)
	high_roller_run.bankroll = maxi(high_roller_target, int(high_roller_run.narrative_flags.get("grand_casino_entry_bankroll", 0)) + high_roller_net)
	high_roller_run.evaluate_environment_objective_state()
	_set_ui_fixture_run(app, high_roller_run)
	var high_roller_snapshot: Dictionary = app.call("current_objective_hud_snapshot")
	if not _assert_objective_state(high_roller_snapshot, "high-roller-ready", "High-roller ready objective HUD"):
		return false
	if not _assert_next_objective(high_roller_snapshot, "travel", "travel:grand_casino_cage", "High-roller ready objective HUD"):
		return false
	high_roller_run.current_environment["event_ids"] = ["high_roller_cashout"]
	if not (app.call("_eligible_event_option_view_list") as Array).is_empty():
		push_error("High-roller Players Card review still appeared on the event surface instead of the Cage.")
		return false
	var ui_generator: RunGenerator = app.get("generator")
	if ui_generator == null or not ui_generator.enter_grand_casino_room(high_roller_run, RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID):
		push_error("High-roller Players Card review could not enter the walkable Cage room.")
		return false
	app.call("_refresh")
	var cage_objects: Dictionary = {}
	for cage_object_value in app.call("_interactable_object_view_list"):
		if typeof(cage_object_value) == TYPE_DICTIONARY:
			cage_objects[str((cage_object_value as Dictionary).get("object_id", ""))] = cage_object_value
	for cage_object_id in ["casino_fixture:cage_counter", "casino_fixture:cage_atm", "casino_fixture:cage_gift_shop", "travel:grand_casino"]:
		if not cage_objects.has(cage_object_id):
			push_error("Walkable Cage did not expose authored object %s." % cage_object_id)
			return false
	var atm_object: Dictionary = cage_objects.get("casino_fixture:cage_atm", {})
	if (atm_object.get("inline_actions", []) as Array).size() != 4:
		push_error("Cage ATM did not expose compact borrow, partial repayment, and payoff controls.")
		return false
	var atm_cash_before := high_roller_run.bankroll
	if not bool(app.call("activate_interactable_object", "cage_atm_action:borrow:50")) or high_roller_run.bankroll != atm_cash_before + 50 or high_roller_run.grand_casino_atm_debt() != 50:
		push_error("Cage ATM inline borrow did not atomically add matching cash and marker debt.")
		return false
	if not bool(app.call("activate_interactable_object", "cage_atm_action:repay:full")) or high_roller_run.bankroll != atm_cash_before or high_roller_run.grand_casino_atm_debt() != 0:
		push_error("Cage ATM inline Pay in Full did not clear the marker from cash.")
		return false
	var gift_actions: Array = (cage_objects.get("casino_fixture:cage_gift_shop", {}) as Dictionary).get("inline_actions", [])
	if gift_actions.size() < 3 or gift_actions.size() > 4 or str((gift_actions[0] as Dictionary).get("emit_object_id", "")).find("cage_gift_action:buy:") != 0:
		push_error("Cage gift case did not expose its 3-4 saved chip-priced offers as focused room controls.")
		return false
	if not bool(app.call("_start_linda_cage_services", {"object_id": "casino_fixture:cage_counter"})):
		push_error("High-roller Players Card review could not open Linda's talk menu.")
		return false
	var ready_cage_model: Dictionary = CageCounterViewModelScript.build(high_roller_run)
	var ready_balance: Dictionary = ready_cage_model.get("balance", {}) if typeof(ready_cage_model.get("balance", {})) == TYPE_DICTIONARY else {}
	var ready_card: Dictionary = ready_cage_model.get("card", {}) if typeof(ready_cage_model.get("card", {})) == TYPE_DICTIONARY else {}
	var ready_talk: Dictionary = app.call("current_talk_dock_snapshot")
	if not bool(ready_talk.get("visible", false)) or not bool(ready_talk.get("portrait_animation_active", false)) or str((ready_cage_model.get("host", {}) as Dictionary).get("name", "")) != "Linda" or str((ready_cage_model.get("host", {}) as Dictionary).get("presentation", "")) != "faceless_silhouette" or (ready_cage_model.get("promotions", []) as Array).is_empty() or int(ready_balance.get("cash", -1)) < 0 or not bool(ready_card.get("can_review", false)):
		push_error("Ready Cage counter did not expose animated silhouette Linda, balances, promotions, and the Players Card review action.")
		return false
	if str(ready_card.get("tier", "")) != "Silver" or str(ready_card.get("progress", "")).find("Gold") == -1 or (ready_cage_model.get("comp_actions", []) as Array).size() != 2:
		push_error("Ready Cage counter did not expose exact Gold progress, benefits, and comp controls.")
		return false
	while not high_roller_run.next_pending_talk_event().is_empty():
		high_roller_run.complete_talk_event_resolution(str(high_roller_run.next_pending_talk_event().get("event_id", "")))
	app.call("_refresh_talk_dock")
	if not bool(app.call("_start_linda_ambient_dialogue", {"object_id": "casino_fixture:cage_counter"})):
		push_error("Bronze-or-better Cage counter did not open Linda's ambient dialogue.")
		return false
	if str(high_roller_run.next_pending_talk_event().get("dialogue_id", "")) != "linda_main_floor_ambient_1":
		push_error("Linda Cage-counter interaction did not use the authored ambient talk scene.")
		return false
	high_roller_run.complete_talk_event_resolution(str(high_roller_run.next_pending_talk_event().get("event_id", "")))
	app.call("_refresh_talk_dock")
	app.call("_complete_cage_players_card_review")
	var gold_review_talk: Dictionary = app.call("current_talk_dock_snapshot")
	if not bool(gold_review_talk.get("visible", false)) or str(high_roller_run.next_pending_talk_event().get("dialogue_id", "")) != "linda_gold_review":
		push_error("Cage Gold review did not move into Linda's talk-dock dialogue scene.")
		return false

	var showdown_run := _grand_casino_fixture_run("UI-HUD-SHOWDOWN", grand_environment)
	showdown_run.add_suspicion("ui_hud_showdown", showdown_heat_threshold, "behavior")
	showdown_run.evaluate_environment_objective_state()
	_set_ui_fixture_run(app, showdown_run)
	var blocked_model: Dictionary = CageCounterViewModelScript.build(showdown_run)
	var blocked_card: Dictionary = blocked_model.get("card", {}) if typeof(blocked_model.get("card", {})) == TYPE_DICTIONARY else {}
	if str(blocked_card.get("review_state", "")) != "blocked" or bool(blocked_card.get("can_review", true)) or str(blocked_card.get("review_detail", "")).find("Rourke") == -1:
		push_error("Cage did not visibly route the blocked Players Card review to Rourke.")
		return false
	var showdown_snapshot: Dictionary = app.call("current_objective_hud_snapshot")
	if not _assert_objective_state(showdown_snapshot, "showdown-pending", "Showdown pending objective HUD"):
		return false
	if not _assert_next_objective(showdown_snapshot, "event", "event:the_house_calls", "Showdown pending objective HUD"):
		return false

	var victory_run := _grand_casino_fixture_run("UI-HUD-VICTORY", grand_environment)
	victory_run.narrative_flags["demo_victory"] = true
	victory_run.narrative_flags["demo_victory_route"] = "high_roller_cashout"
	victory_run.narrative_flags["demo_victory_message"] = RunState.GRAND_CASINO_HIGH_ROLLER_DEFAULT_SUCCESS_MESSAGE
	victory_run.narrative_flags["demo_finale_completed"] = true
	victory_run.run_status = RunState.RUN_STATUS_ENDED
	_set_ui_fixture_run(app, victory_run)
	var victory_snapshot: Dictionary = app.call("current_objective_hud_snapshot")
	if not _assert_objective_state(victory_snapshot, "victory", "Victory objective HUD"):
		return false
	if not _assert_next_objective(victory_snapshot, "menu", "main_menu", "Victory objective HUD"):
		return false

	var failure_run := _grand_casino_fixture_run("UI-HUD-FAILURE", grand_environment)
	failure_run.fail_run(RunState.FAILURE_CASINO_TAKEN_OUT_BACK, RunState.CASINO_TAKEN_OUT_BACK_FAILURE_MESSAGE)
	_set_ui_fixture_run(app, failure_run)
	var failure_snapshot: Dictionary = app.call("current_objective_hud_snapshot")
	if not _assert_objective_state(failure_snapshot, "failure", "Failure objective HUD"):
		return false
	if not _assert_next_objective(failure_snapshot, "menu", "main_menu", "Failure objective HUD"):
		return false
	return true


func _assert_objective_state(snapshot: Dictionary, expected_state: String, label: String) -> bool:
	var actual_state := str(snapshot.get("objective_state", ""))
	if actual_state != expected_state:
		push_error("%s expected objective_state %s but got %s." % [label, expected_state, actual_state])
		return false
	var guidance: Dictionary = snapshot.get("guidance", {})
	if str(guidance.get("state", "")) != expected_state:
		push_error("%s guidance state did not match the HUD state." % label)
		return false
	if str(guidance.get("text", "")).strip_edges().is_empty():
		push_error("%s did not expose player-facing guidance text." % label)
		return false
	if str(snapshot.get("goal", "")).strip_edges().is_empty() or str(snapshot.get("text", "")).find("[GOAL]") == -1:
		push_error("%s did not expose stable visible goal text." % label)
		return false
	return true


func _assert_next_objective(snapshot: Dictionary, expected_type: String, expected_id: String, label: String) -> bool:
	var next_objective: Dictionary = snapshot.get("next_objective", {})
	if str(next_objective.get("object_type", "")) != expected_type or str(next_objective.get("object_id", "")) != expected_id:
		push_error("%s pointed next objective at %s/%s instead of %s/%s." % [
			label,
			str(next_objective.get("object_type", "")),
			str(next_objective.get("object_id", "")),
			expected_type,
			expected_id,
		])
		return false
	return true


func _check_preview_focus_keeps_serialized_run_state(app: Control) -> bool:
	var fixture_run: RunState = RunStateScript.new()
	fixture_run.start_new("UI-PREVIEW-FOCUS-NO-MUTATION")
	fixture_run.bankroll = 100
	fixture_run.game_clock_minutes = 20 * 60
	fixture_run.pending_drunk_absorption = [{
		"remaining": 6,
		"interval_msec": 1,
		"next_msec": 0,
		"queued_msec": 0,
	}]
	var environment := {
		"id": "ui_preview_focus_fixture",
		"archetype_id": "corner_store",
		"display_name": "Preview Focus Fixture",
		"kind": "shop",
		"tier": 1,
		"turns": 0,
		"game_ids": [],
		"event_ids": ["late_shift_discount"],
		"resolved_event_ids": [],
		"item_offers": [{"id": "creased_luck_card", "price": 8}],
		"service_ids": ["cashier_tip"],
		"lender_hooks": ["street_lender"],
		"next_archetypes": ["bar"],
		"travel_hooks": ["bar"],
		"object_fixtures": ["shopkeeper:merchant"],
	}
	environment["layout"] = EnvironmentInstance.ensure_generated_layout(environment)
	fixture_run.set_environment(environment)
	_set_ui_fixture_run(app, fixture_run)
	app.call("clear_interaction_focus")
	var serialized_before_frame := JSON.stringify(app.call("serialized_run_state"))
	await process_frame
	if serialized_before_frame != JSON.stringify(app.call("serialized_run_state")):
		push_error("Passive UI frame advanced alcohol absorption before confirmation.")
		return false
	if not await _preview_call_keeps_serialized_run_state(app, "event focus", "focus_interactable_object", ["event:late_shift_discount"]):
		return false
	if not await _preview_call_keeps_serialized_run_state(app, "event choice selection", "select_event_choice", ["late_shift_discount", "move_on"]):
		return false
	if not await _preview_call_keeps_serialized_run_state(app, "event popup preview", "activate_interactable_object", ["event:late_shift_discount"]):
		return false
	if not await _preview_call_keeps_serialized_run_state(app, "event popup dismissal", "_hide_event_choice_popup", []):
		return false
	if not await _preview_call_keeps_serialized_run_state(app, "item focus", "focus_interactable_object", ["item:creased_luck_card"]):
		return false
	if not await _preview_call_keeps_serialized_run_state(app, "item selection", "select_item_offer", ["creased_luck_card"]):
		return false
	if not await _preview_call_keeps_serialized_run_state(app, "service focus", "focus_interactable_object", ["service:cashier_tip"]):
		return false
	if not await _preview_call_keeps_serialized_run_state(app, "service selection", "select_service_hook", ["cashier_tip"]):
		return false
	if not await _preview_call_keeps_serialized_run_state(app, "lender focus", "focus_interactable_object", ["lender:street_lender"]):
		return false
	if not await _preview_call_keeps_serialized_run_state(app, "lender selection", "select_lender_hook", ["street_lender"]):
		return false
	if not await _preview_call_keeps_serialized_run_state(app, "travel category preview", "select_action_category", ["travel"]):
		return false
	if not await _preview_call_keeps_serialized_run_state(app, "travel focus", "focus_interactable_object", ["travel:leave"]):
		return false
	if not await _preview_call_keeps_serialized_run_state(app, "travel selection", "select_travel_option", ["bar"]):
		return false
	return await _preview_call_keeps_serialized_run_state(app, "world map preview", "activate_interactable_object", ["travel:leave"])


func _preview_call_keeps_serialized_run_state(app: Control, label: String, method: String, args: Array) -> bool:
	var serialized_before := JSON.stringify(app.call("serialized_run_state"))
	var result: Variant = app.callv(method, args)
	if typeof(result) == TYPE_BOOL and not bool(result):
		push_error("Preview/focus regression fixture could not run %s." % label)
		return false
	await process_frame
	var serialized_after := JSON.stringify(app.call("serialized_run_state"))
	if serialized_before != serialized_after:
		push_error("Preview/focus %s mutated serialized RunState before confirmation." % label)
		return false
	return true


func _set_ui_fixture_run(app: Control, run_state: RunState) -> void:
	app.set("run_state", run_state)
	app.set("current_game", null)
	app.call("_refresh_run_action_service")
	app.call("_refresh_runtime_environment_views")


func _check_grand_casino_spatial_ui(app: Control) -> bool:
	app.call("_invalidate_travel_view_cache")
	var original_run_state: RunState = app.get("run_state")
	var run_state: RunState = RunStateScript.new()
	run_state.from_dict(original_run_state.to_dict())
	_set_ui_fixture_run(app, run_state)
	# This fixture is about door presentation, not card progression. Model an
	# already-issued sequential Silver card explicitly instead of relying on the
	# removed cumulative auto-tier derivation.
	run_state.narrative_flags["grand_casino_players_card_awarded_tier"] = RunState.GRAND_CASINO_PLAYERS_CARD_TIER_SILVER
	run_state.narrative_flags["grand_casino_players_card_tier"] = RunState.GRAND_CASINO_PLAYERS_CARD_TIER_SILVER
	run_state.narrative_flags["grand_casino_high_limit_access"] = true
	run_state.narrative_flags["grand_casino_high_limit_access_method"] = "silver_card"
	var staffing := run_state.grand_casino_staffing_snapshot()
	var assignments: Dictionary = staffing.get("assignments", {}) if typeof(staffing.get("assignments", {})) == TYPE_DICTIONARY else {}
	var constants: Dictionary = staffing.get("constants", {}) if typeof(staffing.get("constants", {})) == TYPE_DICTIONARY else {}
	if assignments.size() != 4 or str((constants.get("rourke", {}) as Dictionary).get("name", "")) != "Rourke" or str((constants.get("linda", {}) as Dictionary).get("name", "")) != "Linda":
		push_error("Grand Casino scene snapshot did not expose rotating staff while keeping Rourke and Linda constant.")
		return false
	var rotated := false
	for _day_index in range(20):
		run_state.advance_game_clock_minutes(1440)
		if bool(run_state.grand_casino_staffing_snapshot().get("rotation_occurred", false)):
			rotated = true
			break
	if not rotated:
		push_error("Grand Casino UI fixture did not reach a seeded staff rotation day.")
		return false
	run_state.set_environment(run_state.current_environment.duplicate(true))
	app.call("_refresh")
	var environment_canvas: Variant = app.get("environment_canvas")
	if environment_canvas == null or not environment_canvas.has_method("current_view_snapshot"):
		push_error("Grand Casino staff presentation fixture could not inspect the environment canvas.")
		return false
	var scene_snapshot: Dictionary = environment_canvas.call("current_view_snapshot")
	var scene_staffing: Dictionary = scene_snapshot.get("grand_casino_staffing", {}) if typeof(scene_snapshot.get("grand_casino_staffing", {})) == TYPE_DICTIONARY else {}
	var entry_cue: Dictionary = scene_snapshot.get("grand_casino_entry_cue", {}) if typeof(scene_snapshot.get("grand_casino_entry_cue", {})) == TYPE_DICTIONARY else {}
	if int(scene_staffing.get("day", 0)) != run_state.game_day() or not bool(scene_staffing.get("rotation_occurred", false)) or str(entry_cue.get("message", "")).find("New faces") == -1:
		push_error("Grand Casino rotated staff or first-entry new-day cue did not reach the environment presentation snapshot.")
		return false
	var objects: Array = app.call("_interactable_object_view_list")
	var objects_by_id: Dictionary = {}
	for object_value in objects:
		if typeof(object_value) == TYPE_DICTIONARY:
			objects_by_id[str((object_value as Dictionary).get("object_id", ""))] = object_value
	for object_id in ["casino_fixture:host_desk", "travel:grand_casino_high_limit", "travel:grand_casino_back_room", "travel:grand_casino_cage"]:
		if not objects_by_id.has(object_id):
			push_error("Grand Casino spatial UI did not expose authored object: %s." % object_id)
			return false
	var back_door: Dictionary = objects_by_id.get("travel:grand_casino_back_room", {})
	if bool(back_door.get("enabled", true)) or str(back_door.get("disabled_reason", "")).find("Rourke") == -1:
		push_error("Grand Casino Back Room door was not visibly locked behind Rourke.")
		return false
	var high_choice: Dictionary = app.call("_travel_choice", RunState.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID)
	if high_choice.is_empty() or not bool(high_choice.get("enabled", false)) or not bool(high_choice.get("local_casino_room", false)) or int(high_choice.get("cost", -1)) != 0 or bool(high_choice.get("high_limit_buy_in", true)) or int(high_choice.get("travel_minutes", 0)) != 5:
		push_error("Grand Casino High-Limit door did not expose Silver-or-better card access without a buy-in.")
		return false
	var table_game: GameModule = app.call("_game_module_for_id", "blackjack")
	if table_game == null:
		push_error("Grand Casino spatial UI could not load blackjack for cash-fallback coverage.")
		return false
	var funding_run := _grand_casino_fixture_run("GC-SPATIAL-CASH-FALLBACK", run_state.current_environment)
	funding_run.bankroll = 100
	funding_run.grand_casino_chips = 5
	var funding: Dictionary = funding_run.fund_grand_casino_table_wager(table_game.get_id(), 25, funding_run.current_environment)
	if not bool(funding.get("ok", false)) or int(funding.get("existing_chips_used", -1)) != 5 or int(funding.get("cash_used", -1)) != 20 or funding_run.bankroll != 80 or funding_run.grand_casino_chips != 25:
		push_error("Grand Casino table UI path did not cover a short chip balance directly from cash.")
		return false
	var funding_overlay: Dictionary = app.call("current_overlay_state_snapshot")
	if bool(funding_overlay.get("event_choice_popup_visible", false)) and str(funding_overlay.get("event_choice_popup_type", "")) == "casino_chip_top_up":
		push_error("Grand Casino cash fallback still opened the removed chip top-up decision.")
		return false
	_set_ui_fixture_run(app, original_run_state)
	return true


func _grand_casino_fixture_run(seed_text: String, environment: Dictionary) -> RunState:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed_text)
	run_state.set_environment(environment.duplicate(true))
	return run_state


func _record_grand_casino_clean_games(run_state: RunState, count: int) -> void:
	for game_index in range(maxi(0, count)):
		run_state.record_grand_casino_game_result({
			"ok": true,
			"type": "game_action",
			"source_id": "blackjack",
			"game_id": "blackjack",
			"action_id": "clean_hud_progress",
			"action_kind": "legal",
			"stake": 10 + game_index,
			"deltas": {
				"story_log": [{
					"type": "game_action",
					"game_id": "blackjack",
					"stake_cost": 10 + game_index,
				}],
			},
			"message": "Clean Grand Casino progress.",
		})


func _grand_casino_environment_for_ui(app: Control) -> Dictionary:
	var library: ContentLibrary = app.get("library")
	var archetype := _archetype_by_id(library, "grand_casino")
	if archetype.is_empty():
		return {}
	var environment := archetype.duplicate(true)
	environment["id"] = "grand_casino_ui_hud_fixture"
	environment["archetype_id"] = "grand_casino"
	environment["display_name"] = "Grand Casino"
	environment["kind"] = "boss"
	environment["game_ids"] = (environment.get("game_pool", []) as Array).duplicate()
	environment["event_ids"] = []
	environment["travel_hooks"] = (environment.get("travel_hooks", []) as Array).duplicate()
	return environment


func _check_lender_acceptance_does_not_open_motel_popup(app: Control) -> bool:
	app.call("start_foundation_run", "UI-CREW-LENDER-NO-MOTEL-POPUP")
	await process_frame
	var library: ContentLibrary = app.get("library")
	if library == null or library.lender("the_crew").is_empty() or library.event("motel_knock").is_empty():
		var lender_found := false if library == null else not library.lender("the_crew").is_empty()
		var event_found := false if library == null else not library.event("motel_knock").is_empty()
		var lender_count := -1 if library == null else library.lenders.size()
		var event_count := -1 if library == null else library.events.size()
		push_error("Crew lender popup regression fixture is missing required content. lender=%s event=%s lender_count=%d event_count=%d." % [str(lender_found), str(event_found), lender_count, event_count])
		return false
	var run_state: RunState = app.get("run_state")
	run_state.bankroll = 1
	run_state.economic_state = "volatile"
	var environment := {
		"id": "ui_crew_lender_interrupt_fixture",
		"archetype_id": "motel",
		"display_name": "Motel Lender Fixture",
		"kind": "shop",
		"tier": 1,
		"turns": 1,
		"game_ids": [],
		"event_ids": ["motel_knock"],
		"resolved_event_ids": [],
		"item_offers": [],
		"service_ids": [],
		"lender_hooks": ["the_crew"],
		"travel_hooks": [],
		"next_archetypes": [],
		"object_fixtures": [],
	}
	environment["layout"] = EnvironmentInstance.ensure_generated_layout(environment)
	run_state.set_environment(environment)
	app.call("clear_interaction_focus")
	app.call("_refresh")
	await process_frame
	if not bool(app.call("select_lender_hook", "the_crew")):
		push_error("Crew lender popup regression fixture could not select The Crew.")
		return false
	await process_frame
	if not bool(app.call("confirm_selected_lender_hook")):
		push_error("Crew lender popup regression fixture could not accept The Crew offer.")
		return false
	await process_frame
	var state: Dictionary = app.call("serialized_run_state")
	if int(state.get("bankroll", 0)) <= 1:
		push_error("Crew lender popup regression fixture did not apply the crew loan.")
		return false
	var crew_debt_found := false
	for debt_value in state.get("debt", []):
		if typeof(debt_value) == TYPE_DICTIONARY and str((debt_value as Dictionary).get("lender_id", "")) == "the_crew":
			crew_debt_found = true
			break
	if not crew_debt_found:
		push_error("Crew lender popup regression fixture did not create the crew marker.")
		return false
	var popup: Dictionary = app.call("current_event_choice_popup_snapshot")
	if bool(popup.get("visible", false)):
		push_error("Accepting The Crew offer opened an unrelated event popup: %s." % str(popup.get("event_id", "")))
		return false
	if not (state.get("pending_triggered_events", []) as Array).is_empty():
		push_error("Accepting The Crew offer enqueued an unrelated triggered event.")
		return false
	return true


func _remove_save_slot(save_service: SaveService, slot_id: String) -> Error:
	if save_service == null:
		return ERR_UNCONFIGURED
	var user_dir := DirAccess.open("user://")
	if user_dir == null:
		return ERR_CANT_OPEN
	for path in [save_service.run_save_path(slot_id), save_service.backup_save_path(slot_id)]:
		if not FileAccess.file_exists(path):
			continue
		var relative_path := str(path).replace("user://", "")
		var remove_error := user_dir.remove(relative_path)
		if remove_error != OK:
			return remove_error
	return OK


func _write_save_slot_text(save_service: SaveService, slot_id: String, text: String) -> bool:
	if save_service == null:
		return false
	var path := save_service.run_save_path(slot_id)
	var absolute_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


func _resolve_visible_event_popup(app: Control, label: String) -> bool:
	var popup: Dictionary = app.call("current_event_choice_popup_snapshot")
	if not bool(popup.get("visible", false)):
		return true
	var popup_type := str(popup.get("popup_type", ""))
	if not ["triggered_event", "unavoidable_event", "interactable_event"].has(popup_type):
		push_error("Unexpected blocking popup type during %s: %s." % [label, popup_type])
		return false
	var choices: Array = popup.get("choices", [])
	if choices.is_empty() or typeof(choices[0]) != TYPE_DICTIONARY:
		push_error("Visible event popup during %s had no resolution choice." % label)
		return false
	var choice: Dictionary = choices[0]
	app.call("resolve_event_choice", str(popup.get("event_id", "")), str(choice.get("id", "")))
	await process_frame
	var after: Dictionary = app.call("current_event_choice_popup_snapshot")
	if bool(after.get("visible", false)) and bool(after.get("blocking", false)):
		push_error("Visible event popup did not resolve during %s." % label)
		return false
	return true


func _check_game_surface_touch_hit_policy() -> bool:
	var touch_canvas: Control = GameSurfaceCanvasScript.new()
	touch_canvas.size = Vector2(900, 320)
	root.add_child(touch_canvas)
	touch_canvas.call("surface_add_hit", Rect2(12, 12, 12, 16), "surface_stake_up")
	touch_canvas.call("surface_add_exact_hit", Rect2(40, 40, 12, 16), "dense_board_probe")
	var snapshot: Dictionary = touch_canvas.call("current_view_snapshot")
	var regions: Array = snapshot.get("surface_hit_actions", [])
	var control_rect := _surface_hit_rect(regions, "surface_stake_up")
	var dense_rect := _surface_hit_rect(regions, "dense_board_probe")
	var touch_activation := {"count": 0, "action": "", "confirm_requested": false}
	touch_canvas.connect("surface_action", func(action: String, _index: int, confirm_requested: bool) -> void:
		touch_activation["count"] = int(touch_activation.get("count", 0)) + 1
		touch_activation["action"] = action
		touch_activation["confirm_requested"] = confirm_requested
	)
	var touch_position: Vector2 = touch_canvas.call("local_position_for_surface_action", "surface_stake_up", -1)
	if touch_position.x < 0.0 or touch_position.y < 0.0:
		touch_canvas.queue_free()
		push_error("Game surface touch route could not expose a local hit position.")
		return false
	var touch_event := InputEventScreenTouch.new()
	touch_event.pressed = true
	touch_event.double_tap = true
	touch_event.position = touch_position
	touch_canvas.call("_gui_input", touch_event)
	touch_canvas.set("last_touch_press_msec", Time.get_ticks_msec() - 500)
	var delayed_mouse_event := InputEventMouseButton.new()
	delayed_mouse_event.button_index = MOUSE_BUTTON_LEFT
	delayed_mouse_event.pressed = true
	delayed_mouse_event.position = touch_position
	touch_canvas.call("_gui_input", delayed_mouse_event)
	if control_rect.size.x < 44.0 or control_rect.size.y < 44.0:
		push_error("Game surface touch controls should expand small hit regions to at least 44x44.")
		return false
	if absf(dense_rect.size.x - 12.0) > 0.001 or absf(dense_rect.size.y - 16.0) > 0.001:
		push_error("Dense game-board hit regions should keep exact geometry to avoid overlapping betting grids.")
		return false
	if int(touch_activation.get("count", 0)) != 1 or str(touch_activation.get("action", "")) != "surface_stake_up" or not bool(touch_activation.get("confirm_requested", false)):
		push_error("Game surface touch input did not activate the expected hit region exactly once.")
		return false
	touch_canvas.call("set_small_screen_mode", true)
	touch_canvas.call("surface_add_hit", Rect2(12, 12, 12, 16), "small_screen_probe")
	var small_snapshot: Dictionary = touch_canvas.call("current_view_snapshot")
	var small_rect := _surface_hit_rect(small_snapshot.get("surface_hit_actions", []), "small_screen_probe")
	touch_canvas.queue_free()
	if not bool(small_snapshot.get("small_screen_mode", false)) or small_rect.size.x < SmallScreenPolicyScript.SURFACE_TOUCH_HIT_SIZE.x or small_rect.size.y < SmallScreenPolicyScript.SURFACE_TOUCH_HIT_SIZE.y:
		push_error("Small-screen game surface did not expand ordinary controls to the phone/tablet hit-target policy.")
		return false
	return true


func _surface_hit_rect(regions: Array, action: String) -> Rect2:
	for region_value in regions:
		if typeof(region_value) != TYPE_DICTIONARY:
			continue
		var region: Dictionary = region_value
		if str(region.get("action", "")) != action:
			continue
		var rect: Variant = region.get("rect", Rect2())
		if typeof(rect) == TYPE_RECT2:
			return rect as Rect2
	return Rect2()


func _surface_hit_groups_disjoint(snapshot: Dictionary, left_actions: Array, right_actions: Array, label: String) -> bool:
	var left_rects := _surface_hit_rects(snapshot, left_actions)
	var right_rects := _surface_hit_rects(snapshot, right_actions)
	if left_rects.is_empty() or right_rects.is_empty():
		push_error("%s could not expose both hit-region groups." % label)
		return false
	for left_rect_value in left_rects:
		if typeof(left_rect_value) != TYPE_RECT2:
			continue
		var left_rect: Rect2 = left_rect_value
		for right_rect_value in right_rects:
			if typeof(right_rect_value) != TYPE_RECT2:
				continue
			var right_rect: Rect2 = right_rect_value
			if left_rect.grow(0.5).intersects(right_rect.grow(0.5)):
				push_error("%s overlap: %s intersects %s." % [label, str(left_rect), str(right_rect)])
				return false
	return true


func _surface_hit_rects(snapshot: Dictionary, actions: Array) -> Array:
	var action_lookup: Dictionary = {}
	for action_value in actions:
		action_lookup[str(action_value)] = true
	var rects: Array = []
	var regions: Array = snapshot.get("surface_hit_actions", [])
	for region_value in regions:
		if typeof(region_value) != TYPE_DICTIONARY:
			continue
		var region: Dictionary = region_value
		if not action_lookup.has(str(region.get("action", ""))):
			continue
		var rect: Variant = region.get("rect", Rect2())
		if typeof(rect) == TYPE_RECT2:
			rects.append(rect as Rect2)
	return rects


func _has_visible_text(node: Node, text: String) -> bool:
	if node == null:
		return false
	if node is CanvasItem and not (node as CanvasItem).visible:
		return false
	if node is Label and (node as Label).text.find(text) != -1:
		return true
	if node is Button and (node as Button).text.find(text) != -1:
		return true
	if node is LineEdit and (node as LineEdit).text.find(text) != -1:
		return true
	for child in node.get_children():
		if _has_visible_text(child, text):
			return true
	return false


func _click_visible_button(node: Node, text: String) -> bool:
	if node == null:
		return false
	if node is CanvasItem and not (node as CanvasItem).visible:
		return false
	if node is Button:
		var button := node as Button
		if not button.disabled and button.text == text:
			button.emit_signal("pressed")
			return true
	for child in node.get_children():
		if _click_visible_button(child, text):
			return true
	return false


func _category_by_id(categories: Array, category_id: String) -> Dictionary:
	for category in categories:
		if typeof(category) == TYPE_DICTIONARY and str((category as Dictionary).get("id", "")) == category_id:
			return (category as Dictionary).duplicate(true)
	return {}


func _interactable_copy_is_concise(objects: Array, label: String) -> bool:
	for object_value in objects:
		if typeof(object_value) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = object_value
		var object_id := str(object_data.get("object_id", "object"))
		for key in ["short_description", "choice_summary", "cost_summary", "risk_summary", "impact_summary", "action_summary", "disabled_reason"]:
			var text := str(object_data.get(key, "")).strip_edges()
			if text.length() > 96:
				push_error("%s %s has oversized %s copy: %s" % [label, object_id, key, text])
				return false
		var effect_text := str(object_data.get("effect_summary", "")).strip_edges()
		if effect_text.length() > 132:
			push_error("%s %s has oversized effect copy: %s" % [label, object_id, effect_text])
			return false
	return true


func _interactable_by_type(objects: Array, object_type: String) -> Dictionary:
	for object_data in objects:
		if typeof(object_data) == TYPE_DICTIONARY and str((object_data as Dictionary).get("object_type", "")) == object_type:
			return (object_data as Dictionary).duplicate(true)
	return {}


func _label_for_object_id(objects: Array, object_id: String) -> String:
	for object_data in objects:
		if typeof(object_data) == TYPE_DICTIONARY and str((object_data as Dictionary).get("object_id", "")) == object_id:
			return str((object_data as Dictionary).get("label", ""))
	return ""


func _object_by_id(objects: Array, object_id: String) -> Dictionary:
	for object_data in objects:
		if typeof(object_data) == TYPE_DICTIONARY and str((object_data as Dictionary).get("object_id", "")) == object_id:
			return (object_data as Dictionary).duplicate(true)
	return {}


func _interactable_object_id_with_prefix(objects: Array, prefix: String) -> bool:
	for object_data in objects:
		if typeof(object_data) == TYPE_DICTIONARY and str((object_data as Dictionary).get("object_id", "")).begins_with(prefix):
			return true
	return false


func _canvas_object_by_id(objects: Array, object_id: String) -> Dictionary:
	for object_data in objects:
		if typeof(object_data) == TYPE_DICTIONARY and str((object_data as Dictionary).get("id", "")) == object_id:
			return (object_data as Dictionary).duplicate(true)
	return {}


func _canvas_has_object_type(objects: Array, object_type: String) -> bool:
	for object_data in objects:
		if typeof(object_data) == TYPE_DICTIONARY and str((object_data as Dictionary).get("type", "")) == object_type:
			return true
	return false


func _canvas_object_id_with_prefix(objects: Array, prefix: String) -> bool:
	for object_data in objects:
		if typeof(object_data) == TYPE_DICTIONARY and str((object_data as Dictionary).get("id", "")).begins_with(prefix):
			return true
	return false


func _hidden_world_map_ids(map_data: Dictionary) -> Array:
	var hidden_ids: Array = []
	for node_value in _copy_array(map_data.get("nodes", [])):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := str(node.get("id", ""))
		var state := str(node.get("state", "hidden"))
		var source := str(node.get("discovery_source", "")).strip_edges()
		var visible := state == "visited" or (state == "revealed" and (bool(node.get("discovered_at_spawn", false)) or bool(node.get("unlocked", false)) or source == "spawn" or source == "event" or source == "travel"))
		if not node_id.is_empty() and not visible:
			hidden_ids.append(node_id)
	return hidden_ids


func _world_map_node_by_id(map_data: Dictionary, node_id: String) -> Dictionary:
	for node_value in _copy_array(map_data.get("nodes", [])):
		if typeof(node_value) == TYPE_DICTIONARY and str((node_value as Dictionary).get("id", "")) == node_id:
			return (node_value as Dictionary).duplicate(true)
	return {}


func _world_map_position_in_bounds(position_value: Variant, bounds: Dictionary) -> bool:
	if typeof(position_value) != TYPE_DICTIONARY:
		return false
	var position: Dictionary = position_value
	var x := float(position.get("x", 0.5))
	var y := float(position.get("y", 0.5))
	var left := float(bounds.get("x", 0.0))
	var top := float(bounds.get("y", 0.0))
	var right := left + float(bounds.get("width", bounds.get("w", 1.0)))
	var bottom := top + float(bounds.get("height", bounds.get("h", 1.0)))
	return x >= left - 0.001 and x <= right + 0.001 and y >= top - 0.001 and y <= bottom + 0.001


func _map_bounds_equal(a: Dictionary, b: Dictionary) -> bool:
	for key in ["x", "y", "width", "height"]:
		if absf(float(a.get(key, -999.0)) - float(b.get(key, 999.0))) > 0.0001:
			return false
	return true


func _map_canvas_size_equal(a: Dictionary, b: Dictionary) -> bool:
	var a_size: Dictionary = a.get("canvas_size", {}) if typeof(a.get("canvas_size", {})) == TYPE_DICTIONARY else {}
	var b_size: Dictionary = b.get("canvas_size", {}) if typeof(b.get("canvas_size", {})) == TYPE_DICTIONARY else {}
	for key in ["x", "y"]:
		if absf(float(a_size.get(key, -999.0)) - float(b_size.get(key, 999.0))) > 0.001:
			return false
	return true


func _map_marker_centers_equal(a: Dictionary, b: Dictionary) -> bool:
	var a_centers := _map_marker_centers(a)
	var b_centers := _map_marker_centers(b)
	if a_centers.keys().size() != b_centers.keys().size():
		return false
	for marker_id_value in a_centers.keys():
		var marker_id := str(marker_id_value)
		if not b_centers.has(marker_id):
			return false
		var a_position: Vector2 = a_centers.get(marker_id, Vector2.ZERO)
		var b_position: Vector2 = b_centers.get(marker_id, Vector2.INF)
		if a_position.distance_to(b_position) > 0.25:
			return false
	return true


func _map_marker_centers(view: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for marker_value in _copy_array(view.get("icon_markers", [])):
		if typeof(marker_value) != TYPE_DICTIONARY:
			continue
		var marker: Dictionary = marker_value
		var marker_id := str(marker.get("id", "")).strip_edges()
		var center_value: Variant = marker.get("screen_center", {})
		if marker_id.is_empty() or typeof(center_value) != TYPE_DICTIONARY:
			continue
		var center: Dictionary = center_value
		result[marker_id] = Vector2(float(center.get("x", 0.0)), float(center.get("y", 0.0)))
	return result


func _map_icon_marker(markers: Array, node_id: String) -> Dictionary:
	for marker_value in markers:
		if typeof(marker_value) != TYPE_DICTIONARY:
			continue
		var marker: Dictionary = marker_value
		if str(marker.get("id", "")) == node_id:
			return marker.duplicate(true)
	return {}


func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


func _event_choice_has_trigger_event(event_definition: Dictionary, choice_id: String) -> bool:
	var payload: Dictionary = event_definition.get("payload", {}) if typeof(event_definition.get("payload", {})) == TYPE_DICTIONARY else {}
	for choice_value in payload.get("choices", []):
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice_data: Dictionary = choice_value
		if str(choice_data.get("id", "")) != choice_id:
			continue
		var consequences: Dictionary = choice_data.get("consequences", {}) if typeof(choice_data.get("consequences", {})) == TYPE_DICTIONARY else {}
		return consequences.has("trigger_event")
	return false


func _category_has_fragment(categories: Array, fragment: String) -> bool:
	for category in categories:
		if typeof(category) != TYPE_DICTIONARY:
			continue
		var category_data: Dictionary = category
		if str(category_data.get("id", "")).findn(fragment) != -1 or str(category_data.get("title", "")).findn(fragment) != -1:
			return true
	return false


func _canvas_object_position_matches_board_spot(object_data: Dictionary, board_spot: Variant) -> bool:
	var expected := _board_spot_to_normalized_position(board_spot)
	if expected.x < 0.0 or expected.y < 0.0:
		return false
	var actual: Variant = object_data.get("position", Vector2(-1.0, -1.0))
	if typeof(actual) != TYPE_VECTOR2:
		return false
	return (actual as Vector2).distance_to(expected) <= 0.001


func _board_spot_to_normalized_position(board_spot: Variant) -> Vector2:
	var point := Vector2(-1.0, -1.0)
	if typeof(board_spot) == TYPE_ARRAY:
		var parts := board_spot as Array
		if parts.size() >= 2:
			point = Vector2(float(parts[0]), float(parts[1]))
	elif typeof(board_spot) == TYPE_DICTIONARY:
		var data := board_spot as Dictionary
		point = Vector2(float(data.get("x", -1.0)), float(data.get("y", -1.0)))
	if point.x < 0.0 or point.y < 0.0:
		return Vector2(-1.0, -1.0)
	var board_size := Vector2(VisualStyleScript.ENVIRONMENT_BOARD_SIZE)
	return Vector2(point.x / board_size.x, point.y / board_size.y)


func _archetype_by_id(library: ContentLibrary, archetype_id: String) -> Dictionary:
	if library == null or archetype_id.is_empty():
		return {}
	for archetype in library.environment_archetypes:
		if typeof(archetype) == TYPE_DICTIONARY and str((archetype as Dictionary).get("id", "")) == archetype_id:
			return (archetype as Dictionary).duplicate(true)
	return {}


func _implemented_game_display_names(library: ContentLibrary) -> Array:
	var result: Array = []
	if library == null:
		return result
	for game_value in library.games:
		if typeof(game_value) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = game_value
		var game_id := str(definition.get("id", ""))
		var module_path := str(definition.get("module_path", ""))
		if game_id.is_empty() or module_path.is_empty():
			continue
		if module_path.ends_with("_ui.gd") or module_path.begins_with("res://data/runtime/"):
			continue
		if not ResourceLoader.exists(module_path):
			continue
		result.append(str(definition.get("display_name", game_id.capitalize())))
	return result


func _canvas_surviving_object_positions_match(before_objects: Array, after_objects: Array, removed_object_id: String) -> bool:
	for object_data in before_objects:
		if typeof(object_data) != TYPE_DICTIONARY:
			continue
		var object_id := str((object_data as Dictionary).get("id", ""))
		if object_id.is_empty() or object_id == removed_object_id:
			continue
		var after_object := _canvas_object_by_id(after_objects, object_id)
		if after_object.is_empty():
			continue
		var before_position: Variant = (object_data as Dictionary).get("position", Vector2(0.5, 0.5))
		var after_position: Variant = after_object.get("position", Vector2(0.5, 0.5))
		if typeof(before_position) != TYPE_VECTOR2 or typeof(after_position) != TYPE_VECTOR2:
			return false
		if (before_position as Vector2).distance_to(after_position as Vector2) > 0.0001:
			return false
	return true


func _card_by_title(cards: Array, title: String) -> Dictionary:
	for card in cards:
		if typeof(card) == TYPE_DICTIONARY and str((card as Dictionary).get("title", "")) == title:
			return (card as Dictionary).duplicate(true)
	return {}
