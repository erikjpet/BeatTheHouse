extends "res://tools/tutorial_guided_run_capture.gd"

const TEST_META_PATH := "user://tutorial_dialogue_cadence_meta.json"
const TEST_PROFILE_PATH := "user://tutorial_dialogue_cadence_profile.json"
const TEST_SAVE_SLOT := "tutorial_dialogue_cadence_check"


func _init() -> void:
	call_deferred("_run_dialogue_trigger_cadence_check")


func _run_dialogue_trigger_cadence_check() -> void:
	OS.set_environment("BTH_META_COLLECTION_PATH", TEST_META_PATH)
	OS.set_environment("BTH_PROFILE_INVENTORY_PATH", TEST_PROFILE_PATH)
	_remove_test_file(TEST_META_PATH)
	_remove_test_file(TEST_PROFILE_PATH)
	root.content_scale_size = Vector2i(1280, 720)
	app = MainScene.instantiate()
	app.set("autosave_slot_id", TEST_SAVE_SLOT)
	app.set("continuous_environment_clock_enabled", false)
	root.add_child(app)
	await _settle(8)
	app.call("start_tutorial_run")
	await _settle(10)
	var run_state: RunState = app.get("run_state")
	if run_state == null:
		_fail("Tutorial dialogue cadence check could not start a run.")
		return

	# Exercise the real item action. It intentionally leaves the app in RESULT,
	# while Pal must match the still-visible room and immediately teach Inventory.
	if not bool(app.call("apply_item_offer", "xray_glasses")):
		_fail("Tutorial X-ray Glasses could not be picked up through the production action.")
		return
	await _settle(4)
	var pickup_coach: Dictionary = app.get("coach_overlay").call("current_snapshot")
	var pickup_talk: Dictionary = app.call("current_talk_dock_snapshot")
	if str(app.get("current_screen")) != "RESULT" \
			or str(app.call("_coach_visible_surface_screen")) != "ENVIRONMENT" \
			or str(pickup_coach.get("lesson_id", "")) != "tutorial_inventory_xray" \
			or str(pickup_talk.get("event_id", "")) != "tutorial_guide:tutorial_inventory_xray":
		_fail("The production X-ray pickup did not trigger Pal's Open Inventory line on the visible room surface: coach=%s talk=%s." % [str(pickup_coach), str(pickup_talk)])
		return
	if not await _tutorial_drunk_coffee_intervention_works(run_state):
		return
	if not await _grand_casino_table_highlight_is_visible():
		return
	if not await _linda_exit_guardrails_are_specific(run_state):
		return
	if not await _pull_tab_peek_reminder_is_explicit(run_state):
		return
	if not _blackjack_count_hand_is_mandatory(run_state):
		return

	# Recovery may consume room actions performed on an eligibility boundary, but
	# it must preserve voiced game lessons until Pal has presented them. This is
	# what keeps table guidance paced for a learner instead of firing in a burst.
	_clear_guide_state()
	_stage_environment("small_underground_casino")
	app.call("enter_game", "blackjack", "blackjack")
	# Let the entry draw/animation callback finish so this fixture owns the next
	# coach boundary instead of racing the production deferred refresh.
	await _settle(190)
	_stage_blackjack_raised_bet_surface()
	_stage_guide_lesson("tutorial_blackjack_raise")
	# The capture helper relaxes triggers to stage arbitrary visual states. Restore
	# the production game ownership used by the recovery guard under test.
	var staged_lesson: Dictionary = app.get("library").call("tutorial_lesson", "tutorial_blackjack_raise")
	staged_lesson["trigger"] = {"game_id": "blackjack"}
	await _settle(8)
	var table_talk_before: Dictionary = app.call("current_talk_dock_snapshot")
	if str(table_talk_before.get("event_id", "")) != "tutorial_guide:tutorial_blackjack_raise":
		_fail("The staged voiced blackjack lesson was not presented before recovery: %s." % str(table_talk_before))
		return
	run_state.narrative_flags["tutorial_actions_performed"] = {"surface_stake_up": true}
	app.call("_complete_preperformed_tutorial_actions")
	var table_talk: Dictionary = app.call("current_talk_dock_snapshot")
	if str(app.get("coach_overlay").call("active_lesson_id")) != "tutorial_blackjack_raise" \
			or str(table_talk.get("event_id", "")) != "tutorial_guide:tutorial_blackjack_raise":
		_fail("A pre-recorded table action skipped Pal's voiced blackjack raise lesson: %s." % str(table_talk))
		return
	if not await _game_dialogue_waits_for_transition(run_state):
		return
	if not await _count_deal_moves_outline_to_live_bubbles(run_state):
		return
	if not await _tutorial_meta_home_handoff_is_forced(run_state):
		return

	var save_service: SaveService = app.get("save_service")
	if save_service != null:
		save_service.clear_run(TEST_SAVE_SLOT)
	_remove_test_file(TEST_META_PATH)
	_remove_test_file(TEST_PROFILE_PATH)
	print("tutorial_dialogue_trigger_cadence_check: PASS")
	quit(0)


func _remove_test_file(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func _tutorial_drunk_coffee_intervention_works(run_state: RunState) -> bool:
	_clear_guide_state()
	run_state.pending_drunk_absorption = []
	run_state.drunk_level = RunState.TUTORIAL_DRUNK_COFFEE_THRESHOLD - 1
	run_state.change_drunk(1)
	if run_state.inventory.has(RunState.TUTORIAL_DRUNK_COFFEE_ITEM_ID) \
			or not run_state.consume_tutorial_drunk_coffee_intervention().is_empty():
		_fail("Reaching exactly 33% Drunk triggered Pal before the player crossed the threshold.")
		return false
	run_state.change_drunk(1)
	app.call("_refresh")
	app.call("_refresh_talk_dock")
	await _settle(4)
	var first_event_id := "tutorial_intervention:drunk_coffee:1"
	var first_entry := run_state.pending_talk_event(first_event_id)
	var first_talk: Dictionary = app.call("current_talk_dock_snapshot")
	if not run_state.inventory.has(RunState.TUTORIAL_DRUNK_COFFEE_ITEM_ID) \
			or str(first_entry.get("current_node", "")) != "drunk_coffee" \
			or str(first_talk.get("event_id", "")) != first_event_id:
		_fail("Crossing above 33% Drunk did not give coffee and immediately queue Pal's active-item lesson: %s." % str(first_talk))
		return false
	app.call("_on_talk_dock_choice_requested", first_event_id, "continue")
	await _settle(3)
	if not bool(app.call("select_active_inventory_item", RunState.TUTORIAL_DRUNK_COFFEE_ITEM_ID)):
		_fail("Pal's Thermos could not be equipped through the production Inventory action.")
		return false
	var drunk_before_use := run_state.drunk_level
	if not bool(app.call("use_active_item_slot")):
		_fail("The equipped Thermos did not open the production active-item confirmation.")
		return false
	app.call("confirm_pending_active_item_use")
	await _settle(5)
	var used_talk: Dictionary = app.call("current_talk_dock_snapshot")
	if run_state.drunk_level >= drunk_before_use \
			or run_state.inventory.has(RunState.TUTORIAL_DRUNK_COFFEE_ITEM_ID) \
			or not run_state.inventory.has("thermos_black_coffee_half") \
			or str(used_talk.get("event_id", "")) != "tutorial_intervention:drunk_coffee_used":
		_fail("Using Pal's coffee did not lower Drunk, advance the item, and conclude the active-item lesson: %s." % str(used_talk))
		return false
	app.call("_on_talk_dock_choice_requested", "tutorial_intervention:drunk_coffee_used", "continue")
	await _settle(2)
	run_state.drunk_level = RunState.TUTORIAL_DRUNK_COFFEE_THRESHOLD
	run_state.change_drunk(1)
	app.call("_refresh")
	app.call("_refresh_talk_dock")
	await _settle(4)
	var repeat_entry := run_state.pending_talk_event("tutorial_intervention:drunk_coffee:2")
	if str(repeat_entry.get("current_node", "")) != "drunk_coffee_repeat" \
			or not run_state.inventory.has(RunState.TUTORIAL_DRUNK_COFFEE_ITEM_ID):
		_fail("A later 33% Drunk crossing did not repeat Pal's warning and replenish the Thermos.")
		return false
	var normal_run := RunState.new()
	normal_run.start_new("NORMAL-DRUNK-COFFEE")
	normal_run.drunk_level = RunState.TUTORIAL_DRUNK_COFFEE_THRESHOLD
	normal_run.change_drunk(1)
	if normal_run.inventory.has(RunState.TUTORIAL_DRUNK_COFFEE_ITEM_ID) \
			or not normal_run.consume_tutorial_drunk_coffee_intervention().is_empty():
		_fail("Pal's tutorial-only Drunk intervention leaked into a normal run.")
		return false
	var absorption_run := RunState.new()
	absorption_run.start_new("TUTORIAL-DRUNK-ABSORPTION", run_state.challenge_config)
	absorption_run.drunk_level = RunState.TUTORIAL_DRUNK_COFFEE_THRESHOLD - 5
	absorption_run.drink_alcohol(16)
	if absorption_run.inventory.has(RunState.TUTORIAL_DRUNK_COFFEE_ITEM_ID):
		_fail("Pal's coffee warning fired before a queued drink actually crossed 33% Drunk.")
		return false
	absorption_run.update_drunk_absorption(absorption_run.simulation_time_msec() + RunState.DRUNK_ABSORPTION_INTERVAL_MSEC + 1)
	if not absorption_run.inventory.has(RunState.TUTORIAL_DRUNK_COFFEE_ITEM_ID) \
			or absorption_run.consume_tutorial_drunk_coffee_intervention().is_empty():
		_fail("Delayed drink absorption crossed 33% without publishing Pal's coffee intervention.")
		return false
	return true


func _linda_exit_guardrails_are_specific(run_state: RunState) -> bool:
	_clear_guide_state()
	if not _stage_environment("grand_casino_cage"):
		_fail("Linda exit guardrail fixture could not stage the Cage.")
		return false
	var completed := {"tutorial_open_linda": true}
	run_state.narrative_flags["tutorial_lessons_completed"] = completed
	run_state.grand_casino_chips = 0
	if not bool(app.call("_start_linda_cage_services", {"object_id": "casino_fixture:cage_counter"})):
		_fail("Linda's production service dialogue could not open for the chip guardrail.")
		return false
	var linda_entry := run_state.next_pending_talk_event()
	app.call("_on_talk_dock_choice_requested", str(linda_entry.get("event_id", "")), "leave_counter")
	await _settle(4)
	var buy_reminder := run_state.next_pending_talk_event()
	if str(buy_reminder.get("dialogue_id", "")) != "tutorial_host_guidance" \
			or str(buy_reminder.get("current_node", "")) != "buy_chips_reminder":
		_fail("Leaving Linda before buying chips did not queue the Host's chip reminder: %s." % str(buy_reminder))
		return false
	app.call("_on_talk_dock_choice_requested", str(buy_reminder.get("event_id", "")), "continue")
	await _settle(2)
	run_state.grand_casino_chips = 25
	completed["tutorial_buy_cage_chips"] = true
	run_state.narrative_flags["tutorial_lessons_completed"] = completed
	app.call("_start_linda_cage_services", {"object_id": "casino_fixture:cage_counter"})
	linda_entry = run_state.next_pending_talk_event()
	app.call("_on_talk_dock_choice_requested", str(linda_entry.get("event_id", "")), "leave_counter")
	await _settle(3)
	if not run_state.next_pending_talk_event().is_empty():
		_fail("The Host repeated the chip reminder after the chip requirement was satisfied: %s." % str(run_state.next_pending_talk_event()))
		return false
	completed["tutorial_reopen_linda"] = true
	run_state.narrative_flags["tutorial_lessons_completed"] = completed
	run_state.narrative_flags["grand_casino_players_card_ready_to_claim"] = true
	run_state.narrative_flags["grand_casino_players_card_ready_tier"] = RunState.GRAND_CASINO_PLAYERS_CARD_TIER_BRONZE
	app.call("_start_linda_cage_services", {"object_id": "casino_fixture:cage_counter"})
	linda_entry = run_state.next_pending_talk_event()
	app.call("_on_talk_dock_choice_requested", str(linda_entry.get("event_id", "")), "leave_counter")
	await _settle(4)
	var card_reminder := run_state.next_pending_talk_event()
	if str(card_reminder.get("dialogue_id", "")) != "tutorial_host_guidance" \
			or str(card_reminder.get("current_node", "")) != "claim_card_reminder":
		_fail("Leaving Linda before claiming Bronze did not queue the Host's Players Card reminder: %s." % str(card_reminder))
		return false
	app.call("_on_talk_dock_choice_requested", str(card_reminder.get("event_id", "")), "continue")
	await _settle(2)
	completed["tutorial_claim_bronze"] = true
	run_state.narrative_flags["tutorial_lessons_completed"] = completed
	run_state.narrative_flags["grand_casino_players_card_ready_to_claim"] = false
	run_state.narrative_flags["grand_casino_players_card_ready_tier"] = ""
	run_state.narrative_flags["grand_casino_players_card_tier"] = RunState.GRAND_CASINO_PLAYERS_CARD_TIER_BRONZE
	run_state.narrative_flags["grand_casino_players_card_awarded_tier"] = RunState.GRAND_CASINO_PLAYERS_CARD_TIER_BRONZE
	app.call("_start_linda_cage_services", {"object_id": "casino_fixture:cage_counter"})
	linda_entry = run_state.next_pending_talk_event()
	app.call("_on_talk_dock_choice_requested", str(linda_entry.get("event_id", "")), "open_card")
	app.call("_on_talk_dock_choice_requested", str(linda_entry.get("event_id", "")), "cage_finish_tutorial_card")
	await _settle(3)
	var finish_entry := run_state.next_pending_talk_event()
	if str(finish_entry.get("dialogue_id", "")) != "tutorial_linda_bronze_finish" \
			or str(finish_entry.get("current_node", "")) != "goal":
		_fail("Returning to Linda after Bronze did not expose the resumable Players Card handoff: %s." % str(finish_entry))
		return false
	app.call("_on_talk_dock_choice_requested", str(finish_entry.get("event_id", "")), "review_persistence")
	app.call("_on_talk_dock_choice_requested", str(finish_entry.get("event_id", "")), "review_next_goal")
	app.call("_on_talk_dock_choice_requested", str(finish_entry.get("event_id", "")), "walk_away_card")
	await _settle(4)
	var collect_reminder := run_state.next_pending_talk_event()
	if str(collect_reminder.get("dialogue_id", "")) != "tutorial_host_guidance" \
			or str(collect_reminder.get("current_node", "")) != "collect_card_reminder":
		_fail("Walking away from Linda's final handoff did not queue the Host's collect-card reminder: %s." % str(collect_reminder))
		return false
	app.call("_on_talk_dock_choice_requested", str(collect_reminder.get("event_id", "")), "continue")
	await _settle(2)
	app.call("_start_linda_cage_services", {"object_id": "casino_fixture:cage_counter"})
	linda_entry = run_state.next_pending_talk_event()
	app.call("_on_talk_dock_choice_requested", str(linda_entry.get("event_id", "")), "open_card")
	app.call("_on_talk_dock_choice_requested", str(linda_entry.get("event_id", "")), "cage_finish_tutorial_card")
	await _settle(3)
	finish_entry = run_state.next_pending_talk_event()
	if str(finish_entry.get("dialogue_id", "")) != "tutorial_linda_bronze_finish" \
			or str(finish_entry.get("current_node", "")) != "goal":
		_fail("The Players Card handoff could not be selected again after the Host redirected the player: %s." % str(finish_entry))
		return false
	run_state.complete_talk_event_resolution(str(finish_entry.get("event_id", "")))
	return true


func _grand_casino_table_highlight_is_visible() -> bool:
	if not _stage_environment("grand_casino"):
		_fail("Grand Casino tutorial highlight fixture could not stage the Main Floor.")
		return false
	_stage_guide_lesson("tutorial_enter_grand_table")
	app.call("_refresh_coach_at_boundary")
	await _settle(8)
	var coach_snapshot: Dictionary = app.get("coach_overlay").call("current_snapshot")
	var anchor_rect: Dictionary = coach_snapshot.get("anchor_rect", {}) if typeof(coach_snapshot.get("anchor_rect", {})) == TYPE_DICTIONARY else {}
	var object_ids: Array = []
	for object_value in app.call("_interactable_object_view_list"):
		if typeof(object_value) == TYPE_DICTIONARY:
			object_ids.append(str((object_value as Dictionary).get("object_id", "")))
	if str(coach_snapshot.get("lesson_id", "")) != "tutorial_enter_grand_table" \
			or str(coach_snapshot.get("anchor_id", "")) != "game:blackjack" \
			or not bool(coach_snapshot.get("anchor_found", false)) \
			or float(anchor_rect.get("w", 0.0)) <= 0.0 \
			or float(anchor_rect.get("h", 0.0)) <= 0.0 \
			or str(app.get("selected_object_id")) != "game:blackjack":
		_fail("Grand Casino blackjack lesson did not resolve a visible table highlight: coach=%s objects=%s." % [str(coach_snapshot), str(object_ids)])
		return false
	var blackjack: GameModule = app.call("_game_module_for_id", "blackjack")
	var run_state: RunState = app.get("run_state")
	var natural_ui := {
		"player_hands": [{"cards": [{"rank": 14, "suit": 0}, {"rank": 13, "suit": 1}]}],
		"dealer_cards": [{"rank": 9, "suit": 2}, {"rank": 7, "suit": 3}],
		"active_hand_index": 0,
		"selected_stake": 5,
		"surface_time_msec": 12000,
	}
	var tutorial_environment := run_state.current_environment
	if blackjack.surface_needs_auto_tick(natural_ui, run_state, tutorial_environment) \
			or bool(blackjack.surface_auto_action_command(natural_ui, run_state, tutorial_environment).get("handled", false)):
		_fail("The Grand Casino tutorial still auto-settled a natural blackjack instead of waiting for SETTLE.")
		return false
	var manual_settle := blackjack.surface_action_command("blackjack_deal", 0, true, natural_ui, run_state, tutorial_environment)
	if not bool(manual_settle.get("handled", false)) \
			or str(manual_settle.get("action_id", "")) != "play_basic" \
			or not bool(manual_settle.get("resolve", false)):
		_fail("The Grand Casino tutorial natural did not remain settleable from the explicit SETTLE control: %s." % str(manual_settle))
		return false
	var earlier_tutorial_environment := tutorial_environment.duplicate(true)
	earlier_tutorial_environment["archetype_id"] = "small_underground_casino"
	var normal_run := RunState.new()
	normal_run.start_new("NORMAL-GRAND-NATURAL")
	var normal_environment := tutorial_environment.duplicate(true)
	normal_run.current_environment = normal_environment
	if not blackjack.surface_needs_auto_tick(natural_ui, run_state, earlier_tutorial_environment) \
			or not blackjack.surface_needs_auto_tick(natural_ui, normal_run, normal_environment):
		_fail("Manual natural settlement leaked beyond the one Grand Casino tutorial table.")
		return false
	return true


func _pull_tab_peek_reminder_is_explicit(run_state: RunState) -> bool:
	_clear_guide_state()
	_stage_environment("gas_station_casino")
	app.call("enter_game", "pull_tabs", "pull_tabs")
	await _settle(8)
	_stage_guide_lesson("tutorial_gas_peek")
	await _settle(5)
	app.call("_on_talk_dock_choice_requested", "tutorial_guide:tutorial_gas_peek", "continue")
	await _settle(3)
	var reminder_id := "tutorial_intervention:pull_tab_peek_progress"
	for attempt in range(1, 5):
		# Peek is intentionally a two-step risky action: select, then confirm.
		app.call("_on_game_surface_action", "pull_tab_detector_scan", 0, false)
		app.call("_on_game_surface_action", "pull_tab_detector_scan", 0, false)
		await _settle(8)
		var peek_count := int((app.get("current_game") as GameModule).coach_state(run_state, run_state.current_environment, {}).get("peek_count", 0))
		if peek_count != attempt:
			_fail("Pull Tab tutorial recorded %d Peeks after attempt %d." % [peek_count, attempt])
			return false
		if attempt >= 4:
			if not run_state.pending_talk_event(reminder_id).is_empty():
				_fail("The completed Pull Tab Peek sequence left its progress reminder queued.")
				return false
			continue
		var reminder := run_state.pending_talk_event(reminder_id)
		var reminder_talk: Dictionary = app.call("current_talk_dock_snapshot")
		if str(reminder.get("current_node", "")) != "gas_peek_again_%d" % (4 - attempt) \
				or str(reminder_talk.get("event_id", "")) != reminder_id:
			_fail("Pal did not state the remaining Pull Tab Peeks after attempt %d: %s." % [attempt, str(reminder_talk)])
			return false
		# Do not dismiss this intervention. The next Peek must advance this same
		# visible event instead of adding another reminder behind it.
	return true


func _blackjack_count_hand_is_mandatory(live_run: RunState) -> bool:
	# Keep this mechanics proof isolated from the UI cadence run: settling hands
	# can legitimately advance that run's objectives and would pollute later visual
	# fixtures even though the blackjack contract itself passed.
	var run_state := RunState.new()
	run_state.start_new("TUTORIAL-COUNT-MANDATORY", live_run.challenge_config)
	run_state.set_environment({
		"id": "tutorial_count_fixture",
		"archetype_id": "small_underground_casino",
		"kind": "casino",
		"game_states": {},
	})
	var game: GameModule = BlackjackGame.new()
	var library: ContentLibrary = app.get("library")
	game.setup(library.game("blackjack"), library)
	run_state.bankroll = maxi(run_state.bankroll, 200)
	game.surface_state(run_state, run_state.current_environment, {})
	var game_states: Dictionary = run_state.current_environment.get("game_states", {})
	var table: Dictionary = game_states.get("blackjack", {})
	table["hands_played"] = 1
	table["last_result"] = {"summary": "First tutorial hand settled."}
	table.erase("tutorial_count_completed")
	table.erase("tutorial_count_perfect")
	game_states["blackjack"] = table
	run_state.current_environment["game_states"] = game_states

	# Reproduce the old bypass after the one-time warning was already consumed.
	# The practice hand must still remain playable and Count must remain incomplete.
	run_state.narrative_flags["tutorial_blackjack_peek_reprieve_used"] = true
	var peek_deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 4}, run_state, run_state.current_environment)
	var peek_state: Dictionary = peek_deal.get("ui_state", {})
	var caught := BlackjackAuthorityTestDriverScript.resolve(game, "peek_hole_card", 0, run_state, run_state.current_environment, run_state.create_rng("tutorial_count_required_caught"), peek_state)
	var protected_state: Dictionary = caught.get("blackjack_surface_ui_state", {})
	table = run_state.current_environment.get("game_states", {}).get("blackjack", {})
	if not bool(caught.get("blackjack_tutorial_peek_reprieve", false)) \
			or bool(caught.get("blackjack_table_barred", true)) \
			or bool(table.get("barred", true)) \
			or protected_state.is_empty() \
			or not TutorialFlow.apply_caught_transition(run_state, caught).is_empty():
		_fail("A repeated/resumed tutorial Peek still barred blackjack or bypassed Count: %s." % str(caught))
		return false
	var peek_settlement := BlackjackAuthorityTestDriverScript.resolve(game, "play_basic", 4, run_state, run_state.current_environment, run_state.create_rng("tutorial_count_required_peek_finish"), protected_state)
	if not bool(peek_settlement.get("ok", false)):
		_fail("The protected Peek hand could not be settled before counting: %s." % str(peek_settlement))
		return false
	table = run_state.current_environment.get("game_states", {}).get("blackjack", {})
	if int(table.get("hands_played", 0)) != 2 or bool(table.get("tutorial_count_completed", false)):
		_fail("Settling the Peek hand did not arrive at an incomplete third-hand Count boundary: %s." % str(table))
		return false

	var count_toggle := game.surface_action_command("blackjack_count_toggle", 0, false, {"selected_stake": 4}, run_state, run_state.current_environment)
	var count_deal := game.surface_action_command("blackjack_deal", 0, false, count_toggle.get("ui_state", {}), run_state, run_state.current_environment)
	var count_state: Dictionary = count_deal.get("ui_state", {})
	var challenge: Dictionary = count_state.get("count_challenge", {})
	var icons: Array = challenge.get("icons", [])
	if icons.is_empty():
		_fail("The required third blackjack hand did not create the counting bubbles.")
		return false
	count_state["surface_time_msec"] = 0
	for icon_value in icons:
		var icon: Dictionary = icon_value
		icon["spawn_msec"] = 0
		icon["duration_msec"] = 60000
	challenge["icons"] = icons
	count_state["count_challenge"] = challenge
	for icon_index in range(icons.size()):
		count_state = game.surface_action_command("blackjack_count_icon", icon_index, false, count_state, run_state, run_state.current_environment).get("ui_state", count_state)
	var pre_settle_coach := game.coach_state(run_state, run_state.current_environment, count_state)
	if not bool(pre_settle_coach.get("count_all_selected", false)) \
			or bool(pre_settle_coach.get("tutorial_count_completed", false)):
		_fail("Selecting the count bubbles either failed or falsely completed the lesson before hand settlement: %s." % str(pre_settle_coach))
		return false
	var count_settlement := BlackjackAuthorityTestDriverScript.resolve(game, "play_basic", 4, run_state, run_state.current_environment, run_state.create_rng("tutorial_count_required_settle"), count_state)
	if not bool(count_settlement.get("ok", false)):
		_fail("The counting hand could not settle through normal blackjack logic: %s." % str(count_settlement))
		return false
	var settled_coach := game.coach_state(run_state, run_state.current_environment, {})
	if int(settled_coach.get("hands_played", 0)) != 3 \
			or not bool(settled_coach.get("between_hands", false)) \
			or not bool(settled_coach.get("tutorial_count_completed", false)):
		_fail("The real third-hand count proof did not survive surface-state cleanup: %s." % str(settled_coach))
		return false
	var leave_lesson := library.tutorial_lesson("tutorial_leave_blackjack")
	var leave_context := {
		"run": {"tutorial": true},
		"screen": "GAME",
		"environment_archetype": "small_underground_casino",
		"game_id": "blackjack",
		"game": {"tutorial_count_completed": false, "hands_played": 3, "between_hands": true},
	}
	if CoachViewModel.trigger_matches(leave_lesson, leave_context, {"tutorial_blackjack_count_finish": true}, false):
		_fail("Leave became eligible without persisted proof of the counting lesson.")
		return false
	leave_context["game"]["tutorial_count_completed"] = true
	if not CoachViewModel.trigger_matches(leave_lesson, leave_context, {"tutorial_blackjack_count_finish": true}, false):
		_fail("Leave did not become eligible after the real counting hand settled.")
		return false

	var legacy_run := RunState.new()
	legacy_run.start_new("TUTORIAL-COUNT-LEGACY", live_run.challenge_config)
	legacy_run.set_environment({
		"id": "tutorial_count_legacy_fixture",
		"archetype_id": "small_underground_casino",
		"kind": "casino",
		"game_states": {"blackjack": {"barred": true, "hands_played": 1, "last_result": {"summary": "Caught."}}},
	})
	legacy_run.narrative_flags["tutorial_caught_continue"] = true
	legacy_run.narrative_flags["tutorial_lessons_completed"] = {
		"tutorial_blackjack_peek": true,
		"tutorial_blackjack_count_start": true,
		"tutorial_blackjack_count_all": true,
	}
	if not TutorialFlow.repair_legacy_blackjack_count_skip(legacy_run):
		_fail("The old caught-Peek Count skip was not migrated back to a playable boundary.")
		return false
	var legacy_table: Dictionary = legacy_run.current_environment.get("game_states", {}).get("blackjack", {})
	var legacy_completed: Dictionary = legacy_run.narrative_flags.get("tutorial_lessons_completed", {})
	if bool(legacy_table.get("barred", true)) \
			or int(legacy_table.get("hands_played", 0)) < 2 \
			or bool(legacy_completed.get("tutorial_blackjack_count_all", false)) \
			or not bool(legacy_completed.get("tutorial_blackjack_peek_finish", false)):
		_fail("Legacy Count-skip migration did not reopen the table and require Count: table=%s completed=%s." % [str(legacy_table), str(legacy_completed)])
		return false
	return true


func _game_dialogue_waits_for_transition(run_state: RunState) -> bool:
	_clear_guide_state()
	run_state.narrative_flags["tutorial_actions_performed"] = {}
	var library: ContentLibrary = app.get("library")
	var coach: CoachOverlay = app.get("coach_overlay")
	var first := library.tutorial_lesson("tutorial_blackjack_raise").duplicate(true)
	var second := library.tutorial_lesson("tutorial_blackjack_raised_deal").duplicate(true)
	first["trigger"] = {"screen": "GAME", "game_id": "blackjack", "state_predicates": []}
	second["trigger"] = {"depends_on": ["tutorial_blackjack_raise"], "screen": "GAME", "game_id": "blackjack", "state_predicates": []}
	coach.set_lessons([first, second])
	coach.begin_tutorial_run({})
	coach.evaluate_at_boundary(app.call("_coach_context_snapshot"))
	app.call("_refresh_talk_dock")
	await _settle(3)
	if coach.active_lesson_id() != "tutorial_blackjack_raise":
		_fail("Transition cadence fixture could not activate its first voiced table lesson.")
		return false
	var canvas: Control = app.get("game_surface_canvas")
	canvas.call("apply_surface_state_patch", {"surface_animation_channels": [{
		"id": "tutorial_cadence_fixture",
		"active": true,
		"active_id": "hand_result",
		"duration_msec": 60000,
	}]})
	coach.notify_action("surface_stake_up")
	await _settle(5)
	if not coach.active_lesson_id().is_empty() \
			or not run_state.pending_talk_event("tutorial_guide:tutorial_blackjack_raised_deal").is_empty():
		_fail("Pal started the next table lesson before the finite hand animation finished.")
		return false
	canvas.call("apply_surface_state_patch", {"surface_animation_channels": []})
	await _settle(8)
	var next_talk: Dictionary = app.call("current_talk_dock_snapshot")
	if coach.active_lesson_id() != "tutorial_blackjack_raised_deal" \
			or str(next_talk.get("event_id", "")) != "tutorial_guide:tutorial_blackjack_raised_deal":
		_fail("Pal did not start the next table lesson after the hand animation settled: %s." % str(next_talk))
		return false
	return true


func _count_deal_moves_outline_to_live_bubbles(run_state: RunState) -> bool:
	_clear_guide_state()
	_stage_environment("small_underground_casino")
	app.call("enter_game", "blackjack", "blackjack")
	await _settle(10)
	var game: GameModule = app.get("current_game")
	var game_states: Dictionary = run_state.current_environment.get("game_states", {})
	var table: Dictionary = game_states.get("blackjack", {})
	table["hands_played"] = 2
	table["last_result"] = {"summary": "Peek hand settled."}
	table["counting_enabled"] = false
	table.erase("tutorial_count_completed")
	game_states["blackjack"] = table
	run_state.current_environment["game_states"] = game_states
	app.set("game_surface_ui_state", {})
	var library: ContentLibrary = app.get("library")
	var coach: CoachOverlay = app.get("coach_overlay")
	coach.set_lessons([
		library.tutorial_lesson("tutorial_blackjack_peek_finish"),
		library.tutorial_lesson("tutorial_blackjack_count_start"),
		library.tutorial_lesson("tutorial_blackjack_count_all"),
	])
	coach.begin_tutorial_run({"tutorial_blackjack_peek_finish": true})
	coach.evaluate_at_boundary(app.call("_coach_context_snapshot"))
	app.call("_refresh_talk_dock")
	await _settle(4)
	if coach.active_lesson_id() != "tutorial_blackjack_count_start":
		_fail("The live Count lesson fixture did not begin at Count Start: coach=%s context=%s lesson=%s." % [str(coach.current_snapshot()), str(app.call("_coach_context_snapshot")), str(library.tutorial_lesson("tutorial_blackjack_count_start"))])
		return false
	app.call("_on_talk_dock_choice_requested", "tutorial_guide:tutorial_blackjack_count_start", "continue")
	await _settle(3)
	app.call("_on_game_surface_action", "blackjack_count_toggle", 0, false)
	await _settle(4)
	if coach.active_lesson_id() != "tutorial_blackjack_count_start" \
			or coach.active_anchor_id() != "blackjack_deal":
		_fail("Arming Count did not move the tutorial outline to the live Deal control: %s." % str(coach.current_snapshot()))
		return false
	app.call("_on_game_surface_action", "blackjack_deal", 0, false)
	await _settle(190)
	var context: Dictionary = app.call("_coach_context_snapshot")
	var game_context: Dictionary = context.get("game", {})
	if coach.active_lesson_id() != "tutorial_blackjack_count_all" \
			or coach.active_anchor_id() != "blackjack_count_icon" \
			or not bool(game_context.get("hand_active", false)) \
			or not bool(game_context.get("count_started", false)):
		_fail("Dealing the counting hand left the obsolete Deal outline instead of advancing to live count bubbles: coach=%s game=%s." % [str(coach.current_snapshot()), str(game_context)])
		return false
	return true


func _tutorial_meta_home_handoff_is_forced(run_state: RunState) -> bool:
	_clear_guide_state()
	if not _stage_environment("grand_casino_cage"):
		_fail("Tutorial Home handoff fixture could not stage Linda's Cage.")
		return false
	run_state.narrative_flags["grand_casino_players_card_tier"] = RunState.GRAND_CASINO_PLAYERS_CARD_TIER_BRONZE
	run_state.narrative_flags["grand_casino_players_card_awarded_tier"] = RunState.GRAND_CASINO_PLAYERS_CARD_TIER_BRONZE
	run_state.narrative_flags["grand_casino_players_card_ready_to_claim"] = false
	if not bool(app.call("_resume_tutorial_linda_bronze_finish")):
		_fail("Linda's final Players Card handoff could not start for the Home transition fixture.")
		return false
	var finish_entry := run_state.next_pending_talk_event()
	app.call("_on_talk_dock_choice_requested", str(finish_entry.get("event_id", "")), "review_persistence")
	app.call("_on_talk_dock_choice_requested", str(finish_entry.get("event_id", "")), "review_next_goal")
	app.call("_on_talk_dock_choice_requested", str(finish_entry.get("event_id", "")), "finish_tutorial")
	await _settle(14)
	var home_run: RunState = app.get("run_state")
	var coach_snapshot: Dictionary = app.get("coach_overlay").call("current_snapshot")
	if home_run == null \
			or not bool(home_run.narrative_flags.get("_meta_home_session", false)) \
			or str(home_run.challenge_config.get("id", "")) != "tutorial_meta_home_handoff" \
			or str(coach_snapshot.get("lesson_id", "")) != "tutorial_meta_home_card" \
			or not str(app.get("selected_object_id")).begins_with("meta_container:"):
		_fail("Taking Linda's card did not force the highlighted Meta Home tutorial: run=%s coach=%s selected=%s context=%s lesson=%s." % [str(home_run.challenge_config if home_run != null else {}), str(coach_snapshot), str(app.get("selected_object_id")), str(app.call("_coach_context_snapshot")), str(app.get("library").call("tutorial_lesson", "tutorial_meta_home_card"))])
		return false
	app.call("open_meta_container")
	await _settle(5)
	var home_inventory: Dictionary = app.call("current_meta_item_interaction_snapshot")
	var found_starter_card := false
	var meta_service: MetaCollectionService = app.get("meta_collection_service")
	for item_value in meta_service.owned_instances():
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_value
		var instance_data: Dictionary = item.get("instance_data", {}) if typeof(item.get("instance_data", {})) == TYPE_DICTIONARY else {}
		if str(item.get("item_class", "")) == "players_card" \
				and bool(instance_data.get("starter_card", false)) \
				and meta_service.carried_instance_ids().has(int(item.get("instance_id", 0))):
			found_starter_card = true
			break
	coach_snapshot = app.get("coach_overlay").call("current_snapshot")
	if not bool(home_inventory.get("visible", false)) \
			or int(home_inventory.get("item_count", 0)) <= 0 \
			or not found_starter_card \
			or str(coach_snapshot.get("lesson_id", "")) == "tutorial_meta_home_card":
		_fail("Opening the highlighted Home Bag did not reveal the packed starter card and complete the Home lesson: inventory=%s coach=%s." % [str(home_inventory), str(coach_snapshot)])
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
