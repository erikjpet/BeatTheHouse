class_name PlaytestFixes03Contract
extends RefCounted

const CoachOverlayScript := preload("res://scripts/ui/coach_overlay.gd")
const BlackjackGameScript := preload("res://scripts/games/blackjack.gd")
const CrapsGameScript := preload("res://scripts/games/craps.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const FoundationMainScript := preload("res://scripts/ui/foundation_main.gd")
const MetaCollectionServiceScript := preload("res://scripts/core/meta_collection_service.gd")
const RunActionServiceScript := preload("res://scripts/core/run_action_service.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const SettingsMenuScript := preload("res://scripts/ui/settings_menu.gd")
const SlotGameScript := preload("res://scripts/games/slot.gd")
const TalkDockScript := preload("res://scripts/ui/talk_dock.gd")
const UserSettingsScript := preload("res://scripts/core/user_settings.gd")


class RenderedHudProbe:
	extends RefCounted

	var rendered: Dictionary = {}

	func set_reduce_motion(_enabled: bool) -> void:
		pass

	func set_compact_mode(_enabled: bool) -> void:
		pass

	func render(model: Dictionary) -> void:
		rendered = model.duplicate(true)


class CountPulseSurfaceProbe:
	extends RefCounted

	var now_msec := 0
	var exact_hits: Array = []

	func surface_simulation_time_msec() -> int:
		return now_msec

	func draw_rect(_rect: Rect2, _color: Color, _filled := true, _width := -1.0, _antialiased := false) -> void:
		pass

	func draw_circle(_position: Vector2, _radius: float, _color: Color, _filled := true, _width := -1.0, _antialiased := false) -> void:
		pass

	func surface_label(_text: String, _position: Vector2, _size: int, _color: Color) -> void:
		pass

	func surface_label_centered(_text: String, _rect: Rect2, _size: int, _color: Color) -> void:
		pass

	func surface_add_exact_hover_hit(rect: Rect2, action_id: String, payload: Variant) -> void:
		exact_hits.append({"rect": rect, "action_id": action_id, "payload": payload})


class NumbersHudHostProbe:
	extends FoundationMainScript

	func _refresh_embedded_action_hud() -> void:
		structured_hud.render({
			"bankroll": run_state.bankroll,
			"bankroll_delta": int(last_hook_result.get("bankroll_delta", 0)),
		})


static func check(library, failures: Array) -> void:
	_check_bug07_tutorial_dialogue_input_ownership(failures)
	_check_bug08_09_numbers_wallet_render(library, failures)
	_check_bug12_double_click_purchase_selection(library, failures)
	_check_bug19_fixed_seed_explanation(failures)
	_check_bug23_settings_focus_scroll(failures)
	_check_bug30_production_chain_nameplate(library, failures)
	_check_bug31_lucky_terms_survive_render(library, failures)
	_check_bug32_blackjack_count_pulse_identity(failures)
	_check_bug33_explicit_run_home_precedence(failures)
	_check_bug35_pinball_zero_ball_settlement(failures)
	_check_bug36_craps_refund_funding_wallet(failures)


static func _check_bug07_tutorial_dialogue_input_ownership(failures: Array) -> void:
	var coach := CoachOverlayScript.new()
	var dock := TalkDockScript.new()
	dock.position = Vector2(100.0, 100.0)
	dock.size = Vector2(420.0, 240.0)
	dock.visible = true
	var talk_choice := Button.new()
	talk_choice.position = Vector2(24.0, 150.0)
	talk_choice.size = Vector2(180.0, 48.0)
	talk_choice.mouse_filter = Control.MOUSE_FILTER_STOP
	dock.add_child(talk_choice)
	coach.visible = true
	coach.active_lesson = {"scope": "tutorial_run", "id": "bug07_input_owner"}
	if not coach.has_method("set_tutorial_input_owner"):
		failures.append("BUG-07 regression: CoachOverlay cannot register the tutorial TalkDock as an input owner.")
	else:
		coach.call("set_tutorial_input_owner", dock)
		var choice_press := InputEventMouseButton.new()
		choice_press.button_index = MOUSE_BUTTON_LEFT
		choice_press.pressed = true
		choice_press.position = Vector2(140.0, 270.0)
		if bool(coach.call("_consume_blocked_pointer_input", choice_press)):
			failures.append("BUG-07 regression: tutorial shield consumes a real TalkDock choice control owned by the active lesson.")
		var room_press := InputEventMouseButton.new()
		room_press.button_index = MOUSE_BUTTON_LEFT
		room_press.pressed = true
		room_press.position = Vector2(700.0, 400.0)
		if bool(coach.call("_consume_blocked_pointer_input", room_press)):
			failures.append("BUG-07 regression: advisory tutorial guidance swallowed an unrelated room control.")
	# Skipping the phone pointer may mark that guidance seen, but it must not make
	# the dependent debt lesson real before the authored debt/result predicates.
	coach.set("lessons", [{
		"id": "tutorial_family_debt",
		"scope": "tutorial_run",
		"trigger": {
			"depends_on": ["tutorial_family_phone"],
			"screen": "ENVIRONMENT",
			"environment_archetype": "corner_store",
			"state_predicates": [
				{"path": "run.debt_count", "op": "gte", "value": 1},
				{"path": "run.flags.tutorial_family_loan_dialogue_resolved", "op": "equals", "value": true},
			],
		},
		"anchor": {"kind": "hud_element", "id": "debt"},
		"completion": {"type": "explicit_ok"},
	}])
	coach.set("seen", {"tutorial_family_phone": true})
	coach.call("_queue_frontier_guardrail", {
		"screen": "ENVIRONMENT",
		"environment_archetype": "corner_store",
		"run": {"tutorial": true, "debt_count": 0, "flags": {}},
	})
	if not (coach.get("queued_lessons") as Array).is_empty():
		failures.append("BUG-07 follow-up regression: skipping the phone pointer queues debt guidance before a phone outcome creates debt.")
	coach.free()
	dock.free()


static func _check_bug08_09_numbers_wallet_render(library, failures: Array) -> void:
	for case_value in [
		{"action_id": "buy_slip", "source_id": "numbers_book", "cost": 1, "bug": "BUG-08"},
		{"action_id": "buy_route_tip", "source_id": "silas", "cost": 12, "bug": "BUG-09"},
	]:
		var case_data: Dictionary = case_value
		var run_state = RunStateScript.new()
		run_state.start_new("PLAYTEST-FIXES03-%s" % str(case_data.bug))
		run_state.bankroll = 100
		var host := NumbersHudHostProbe.new()
		var hud := RenderedHudProbe.new()
		host.run_state = run_state
		host.library = library
		host.structured_hud = hud
		hud.rendered = {"bankroll": 100, "bankroll_delta": 0}
		var cost := int(case_data.cost)
		run_state.bankroll -= cost
		host.call("_publish_numbers_result", {
			"ok": true,
			"message": "Exchange complete.",
			"bankroll_delta": -cost,
			"deltas": {"bankroll_delta": -cost},
		}, str(case_data.action_id), str(case_data.source_id))
		if int(hud.rendered.get("bankroll", -1)) != run_state.bankroll or int(hud.rendered.get("bankroll_delta", 0)) != -cost:
			failures.append("%s regression: Numbers result publishes internally but the rendered HUD remains stale (%s vs bankroll %d delta %d)." % [str(case_data.bug), hud.rendered, run_state.bankroll, -cost])
		host.free()


static func _check_bug12_double_click_purchase_selection(library, failures: Array) -> void:
	var run_state = RunStateScript.new()
	run_state.start_new("PLAYTEST-FIXES03-BUG12")
	run_state.bankroll = 100
	run_state.current_environment = {
		"id": "bug12_corner_store",
		"archetype_id": "corner_store",
		"turns": 0,
		"item_offers": [
			{"id": "instant_coffee", "display_name": "Instant Coffee", "price": 8},
			{"id": "ledger_pencil", "display_name": "Ledger Pencil", "price": 14},
		],
	}
	var host := FoundationMainScript.new()
	host.library = library
	host.run_state = run_state
	host.current_screen = "ITEMS"
	host.selected_object_id = "item:ledger_pencil"
	host.focus_target_id = "item:ledger_pencil"
	host.selected_item_offer_id = "ledger_pencil"
	host.call("_refresh_run_action_service")
	var resolved: Dictionary = host.run_action_service.buy_item_offer("ledger_pencil")
	var purchased := bool(resolved.get("ok", false))
	if purchased:
		host.call("_present_item_purchase_result", resolved.get("result", {}))
	# The next tutorial lesson can enqueue dialogue during this same refresh. That
	# clears generic recent-result fields, but the purchase still owns the room
	# boundary until the player makes a new selection.
	host.call("_clear_recent_result_feedback")
	var rendered_selection: Dictionary = host.current_spatial_interaction_snapshot()
	if not purchased:
		failures.append("BUG-12 regression: the production item purchase path rejected the selected Ledger Pencil fixture.")
	elif str(rendered_selection.get("selected_object_id", "")) != "":
		failures.append("BUG-12 regression: the player-visible room snapshot retains a selected purchase card after its offer was sold (%s)." % rendered_selection)
	if not host.has_method("_item_purchase_result_owns_room_focus") or not bool(host.call("_item_purchase_result_owns_room_focus")):
		failures.append("BUG-12 regression: tutorial refocus can replace the purchased-item result with another shelf card on the same presentation beat.")
	if run_state.bankroll != 86 or not run_state.inventory.has("ledger_pencil") or not host.call("_item_offer", "ledger_pencil").is_empty():
		failures.append("BUG-12 regression: Ledger Pencil purchase did not settle exactly once before the result selection was cleared.")
	var main_source := FileAccess.get_file_as_string("res://scripts/ui/foundation_main.gd")
	var focus_callback_start := main_source.find("func _on_environment_object_focused")
	var focus_callback_end := main_source.find("\nfunc ", focus_callback_start + 8)
	var focus_callback := main_source.substr(focus_callback_start, focus_callback_end - focus_callback_start) if focus_callback_start >= 0 and focus_callback_end > focus_callback_start else ""
	if not focus_callback.contains("pending_post_purchase_affinity_result = {}") or not focus_callback.contains("SCREEN_ENVIRONMENT"):
		failures.append("BUG-12 regression: an explicit player room click cannot dismiss the completed purchase result before inspecting another offer.")
	host.free()


static func _check_bug19_fixed_seed_explanation(failures: Array) -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/ui/foundation_main.gd")
	var builder_source := FileAccess.get_file_as_string("res://scripts/ui/foundation_screen_builder.gd")
	if not main_source.contains("seed_status_label") or not builder_source.contains("host.seed_status_label"):
		failures.append("BUG-19 regression: the disabled First Night seed has no dedicated always-visible explanation beside the field.")


static func _check_bug23_settings_focus_scroll(failures: Array) -> void:
	var menu := SettingsMenuScript.new()
	menu.setup(UserSettingsScript.new())
	var scrolls := menu.find_children("*", "ScrollContainer", true, false)
	var scroll: ScrollContainer = scrolls[0] as ScrollContainer if not scrolls.is_empty() else null
	if scroll == null or not scroll.follow_focus:
		failures.append("BUG-23 regression: Settings focus can move off-screen because its ScrollContainer does not follow the focused control.")
	menu.free()


static func _check_bug30_production_chain_nameplate(library, failures: Array) -> void:
	var run_state = RunStateScript.new()
	run_state.start_new("PLAYTEST-FIXES03-CHAIN-NAMEPLATE", {"tutorial": true, "modifiers": {"tutorial_run": true}})
	run_state.current_environment = {
		"id": "corner_store_contract",
		"archetype_id": "corner_store",
		"kind": "shop",
		"tier": 1,
		"turns": 0,
		"event_ids": ["call_brother_in_law"],
		"resolved_event_ids": [],
	}
	var source := EventModuleScript.new()
	source.setup(library.event("call_brother_in_law"), library)
	var source_result: Dictionary = source.resolve(run_state, run_state.current_environment, "make_call")
	var queued: Dictionary = run_state.pending_talk_event("family_loan")
	if not bool(source_result.get("ok", false)) or queued.is_empty():
		failures.append("BUG-30 regression: production Counter Phone resolution did not enqueue the family-loan TalkDock entry.")
		return
	var family := EventModuleScript.new()
	family.setup(library.event("family_loan"), library)
	var family_choices: Array = family.choices(run_state, run_state.current_environment)
	var dock := TalkDockScript.new()
	dock.size = Vector2(1280.0, 720.0)
	(Engine.get_main_loop() as SceneTree).root.add_child(dock)
	dock.set_entry(queued, {
		"id": "family_loan",
		"display_name": "Family Loan",
		"summary": str((family_choices[0] as Dictionary).get("text", "")) if not family_choices.is_empty() else "",
		"choices": family_choices,
	}, 1)
	var rendered_name := str(dock.speaker_label.text)
	if not rendered_name.contains("Gabe Mercer") or rendered_name.contains("Unknown"):
		failures.append("BUG-30 regression: production chained speaker hydrates internally but the rendered nameplate is '%s'." % rendered_name)
	dock.free()


static func _check_bug31_lucky_terms_survive_render(library, failures: Array) -> void:
	var run_state = RunStateScript.new()
	run_state.start_new("PLAYTEST-FIXES03-LUCKY-TERMS")
	run_state.current_environment = {
		"id": "corner_store_contract",
		"archetype_id": "corner_store",
		"kind": "shop",
		"turns": 0,
		"lender_hooks": ["the_crew"],
	}
	var host := FoundationMainScript.new()
	host.library = library
	host.run_state = run_state
	var dock := TalkDockScript.new()
	dock.size = Vector2(1280.0, 720.0)
	(Engine.get_main_loop() as SceneTree).root.add_child(dock)
	host.talk_dock = dock
	var definition: Dictionary = library.lender("the_crew")
	var normalized_speaker: Dictionary = host.call("_normalized_talk_speaker", definition.get("speaker", {}))
	var speaker: Dictionary = host.call("_resolve_character_speaker", normalized_speaker, "the_crew", "loan_offer")
	var event_id := "lender_conversation:borrow:the_crew"
	run_state.enqueue_triggered_event(event_id, "lender", {
		"trigger": "lender_conversation",
		"type": "lender_conversation",
		"lender_id": "the_crew",
		"lender_mode": "borrow",
	}, {"presentation": "talk", "speaker": speaker})
	host.call("_refresh_talk_dock")
	var rendered_body := str(dock.full_body_text)
	var conversation: Dictionary = host.call("_lender_conversation_option", run_state.pending_talk_event(event_id))
	var choices: Array = conversation.get("choices", [])
	var accept: Dictionary = choices[0] if not choices.is_empty() and typeof(choices[0]) == TYPE_DICTIONARY else {}
	for token in ["$45", "2 favors", "0%", "2 turns"]:
		if not rendered_body.contains(token):
			failures.append("BUG-31 regression: Lucky's rendered offer/confirmation body omits %s (%s)." % [token, rendered_body])
		if not str(accept.get("consequence_summary", "")).contains(token):
			failures.append("BUG-31 regression: Lucky's confirmation consequence omits %s (%s)." % [token, accept.get("consequence_summary", "")])
	if not rendered_body.contains(str(speaker.get("voice_line", ""))):
		failures.append("BUG-31 regression: adding Lucky's obligation terms removed the authored voice line (%s)." % rendered_body)
	var service := RunActionServiceScript.new()
	service.setup(library, run_state)
	var result: Dictionary = service.use_hook("lender", "the_crew")
	for token in ["$45", "2 favors", "0%", "2 turns"]:
		if not str(result.get("message", "")).contains(token):
			failures.append("BUG-31 regression: Lucky's accepted-loan result omits %s (%s)." % [token, result.get("message", "")])
	var continued_run = RunStateScript.new()
	continued_run.from_dict(run_state.to_dict())
	var crew_debt: Dictionary = {}
	for debt_value in continued_run.debt:
		if typeof(debt_value) == TYPE_DICTIONARY and str((debt_value as Dictionary).get("lender_id", "")) == "the_crew":
			crew_debt = debt_value
			break
	if int(crew_debt.get("principal", 0)) != 45 or int(crew_debt.get("balance", 0)) != 2 or str(crew_debt.get("debt_kind", "")) != "favor" or int(crew_debt.get("deadline_turns", 0)) != 2:
		failures.append("BUG-31 regression: disclosed Lucky terms do not match the favor obligation restored by Continue (%s)." % crew_debt)
	host.free()
	dock.free()


static func _check_bug32_blackjack_count_pulse_identity(failures: Array) -> void:
	var game := BlackjackGameScript.new()
	var run_state = RunStateScript.new()
	run_state.start_new("CLAIM06-B2-FLAT-FINAL")
	var opening_cards := [
		_bug32_card(2, 0), _bug32_card(3, 1), _bug32_card(4, 2), _bug32_card(5, 3),
		_bug32_card(6, 0), _bug32_card(12, 1), _bug32_card(8, 2), _bug32_card(13, 3),
	]
	var session := {
		"surface_time_msec": 1000,
		"dealer_cards": [_bug32_card(10, 0)],
		"player_hands": [{"cards": opening_cards}],
		"patron_hands": [],
		"dealer_hole_visible": false,
	}
	game.call("_start_count_challenge", session, {}, run_state, 1000)
	var challenge: Dictionary = session.get("count_challenge", {})
	var opening_ids := _bug32_icon_ids(challenge)
	if opening_ids.size() != 8 or _bug32_unique_strings(opening_ids).size() != opening_ids.size():
		failures.append("BUG-32 regression: CLAIM06-B2-FLAT-FINAL opening count pulses do not have eight unique exact IDs (%s)." % opening_ids)
	challenge["clicked_icons"] = opening_ids.duplicate()
	session["count_challenge"] = challenge
	(session.get("player_hands", []) as Array)[0]["cards"].append(_bug32_card(13, 2))
	var added := int(game.call("_sync_count_challenge_icons", session, run_state, 4000))
	challenge = session.get("count_challenge", {})
	var hit_ids := _bug32_icon_ids(challenge)
	var new_icon_id := str(hit_ids.back()) if not hit_ids.is_empty() else ""
	if added != 1 or hit_ids.size() != 9 or _bug32_unique_strings(hit_ids).size() != hit_ids.size() or opening_ids.has(new_icon_id):
		failures.append("BUG-32 regression: CLAIM06-B2-FLAT-FINAL HIT reuses a resolved pulse ID instead of adding one unique pulse (opening %s, after HIT %s, added %d)." % [opening_ids, hit_ids, added])
	var probe := CountPulseSurfaceProbe.new()
	probe.now_msec = 4300
	game.call("_draw_count_challenge", probe, session)
	var clickable := false
	for hit_value in probe.exact_hits:
		var hit: Dictionary = hit_value
		if str(hit.get("action_id", "")) == "blackjack_count_icon" and int(hit.get("payload", -1)) == hit_ids.size() - 1:
			clickable = true
			break
	if not clickable:
		failures.append("BUG-32 regression: the newly exposed CLAIM06-B2-FLAT-FINAL HIT pulse has no exact blackjack_count_icon action (%s)." % [probe.exact_hits])

	var split_session := {
		"surface_time_msec": 1000,
		"dealer_cards": [_bug32_card(4, 0)],
		"player_hands": [{"cards": [_bug32_card(2, 1), _bug32_card(10, 2)]}],
		"patron_hands": [],
		"dealer_hole_visible": false,
	}
	game.call("_start_count_challenge", split_session, {}, run_state, 1000)
	var split_before: Dictionary = split_session.get("count_challenge", {})
	var split_before_ids := _bug32_icon_ids(split_before)
	var original_cards: Array = (split_session.get("player_hands", []) as Array)[0]["cards"]
	split_session["player_hands"] = [
		{"cards": [original_cards[0], _bug32_card(3, 0)]},
		{"cards": [original_cards[1], _bug32_card(12, 3)]},
	]
	var split_added := int(game.call("_sync_count_challenge_icons", split_session, run_state, 3000))
	var split_after: Dictionary = split_session.get("count_challenge", {})
	var split_after_ids := _bug32_icon_ids(split_after)
	if split_added != 2 or split_after_ids.size() != split_before_ids.size() + 2 or _bug32_unique_strings(split_after_ids).size() != split_after_ids.size():
		failures.append("BUG-32 regression: splitting relocates an exposed card or collides pulse IDs instead of adding exactly two unique draw pulses (before %s, after %s, added %d)." % [split_before_ids, split_after_ids, split_added])
	var split_probe := CountPulseSurfaceProbe.new()
	split_probe.now_msec = 3800
	game.call("_draw_count_challenge", split_probe, split_session)
	var split_clickable_indexes: Array = []
	for hit_value in split_probe.exact_hits:
		var hit: Dictionary = hit_value
		if str(hit.get("action_id", "")) == "blackjack_count_icon":
			split_clickable_indexes.append(int(hit.get("payload", -1)))
	for expected_index in range(split_before_ids.size(), split_after_ids.size()):
		if not split_clickable_indexes.has(expected_index):
			failures.append("BUG-32 regression: split draw pulse %d has no exact blackjack_count_icon action (%s)." % [expected_index, split_probe.exact_hits])

	var save_run = RunStateScript.new()
	save_run.start_new("CLAIM06-B2-FLAT-FINAL-SPLIT-SAVE")
	save_run.current_environment = {"id": "blackjack_count_save", "archetype_id": "casino", "game_states": {"blackjack": {"session": split_session}}}
	var loaded_run = RunStateScript.new()
	loaded_run.from_dict(save_run.to_dict())
	var loaded_session: Dictionary = ((loaded_run.current_environment.get("game_states", {}) as Dictionary).get("blackjack", {}) as Dictionary).get("session", {})
	var loaded_before_ids := _bug32_icon_ids(loaded_session.get("count_challenge", {}))
	var loaded_added := int(game.call("_sync_count_challenge_icons", loaded_session, loaded_run, 3200))
	var loaded_after: Dictionary = loaded_session.get("count_challenge", {})
	var loaded_after_ids := _bug32_icon_ids(loaded_after)
	if loaded_added != 0 or loaded_before_ids != loaded_after_ids or int(loaded_after.get("icon_serial", -1)) != int(split_after.get("icon_serial", -2)):
		failures.append("BUG-32 regression: save/Continue changes Blackjack pulse identity or manufactures another split pulse (before %s, after %s, added %d)." % [loaded_before_ids, loaded_after_ids, loaded_added])


static func _bug32_card(rank: int, suit: int, deck: int = 0) -> Dictionary:
	return {"rank": rank, "suit": suit, "deck": deck}


static func _bug32_icon_ids(challenge: Dictionary) -> Array:
	var ids: Array = []
	for icon_value in challenge.get("icons", []):
		if typeof(icon_value) == TYPE_DICTIONARY:
			ids.append(str((icon_value as Dictionary).get("id", "")))
	return ids


static func _bug32_unique_strings(values: Array) -> Array:
	var unique: Array = []
	for value in values:
		var text := str(value)
		if not unique.has(text):
			unique.append(text)
	return unique


static func _check_bug33_explicit_run_home_precedence(failures: Array) -> void:
	var host := FoundationMainScript.new()
	host.meta_collection_service = MetaCollectionServiceScript.new()
	var explicit: Dictionary = host.call("_challenge_with_meta_home_for_run", "PLAYTEST-FIXES03-HOME", {
		"id": "standard",
		"mode": "standard",
		"seed_text": "PLAYTEST-FIXES03-HOME",
		"modifiers": {"home_archetype_id": "motel_room"},
	})
	var explicit_modifiers: Dictionary = explicit.get("modifiers", {})
	if str(explicit_modifiers.get("home_archetype_id", "")) != "motel_room" or not bool(explicit_modifiers.get("meta_collection_enabled", false)):
		failures.append("BUG-33 regression: Run Content home selection is overwritten instead of preserving the explicit home beside other meta modifiers (%s)." % explicit_modifiers)
	var random: Dictionary = host.call("_challenge_with_meta_home_for_run", "PLAYTEST-FIXES03-HOME-RANDOM", {
		"id": "standard",
		"mode": "standard",
		"seed_text": "PLAYTEST-FIXES03-HOME-RANDOM",
		"modifiers": {},
	})
	if str((random.get("modifiers", {}) as Dictionary).get("home_archetype_id", "")) != "back_alley":
		failures.append("BUG-33 regression: Random/absent home no longer inherits the profile home.")
	host.free()


static func _check_bug35_pinball_zero_ball_settlement(failures: Array) -> void:
	var game := SlotGameScript.new()
	var machine := {
		"active_bonus": {
			"active": true,
			"complete": false,
			"family": "pinball",
			"balls_remaining": 0,
			"remaining_steps": 0,
			"active_ball_count": 0,
		},
	}
	var status: Dictionary = game.call("_slot_bonus_watchdog_status", machine, {"surface_time_msec": 1000})
	if not bool(status.get("due", false)) or not bool(status.get("needs_tick", false)):
		failures.append("BUG-35 regression: a drained zero-ball Pinball feature waits for another launch/watchdog grace period instead of settling on the next host tick (%s)." % status)
	var resolver_source := FileAccess.get_file_as_string("res://scripts/games/slots/slot_resolver.gd")
	if not resolver_source.contains("family_id == \"pinball\" and not complete") or not resolver_source.contains("step[\"award\"] = 0"):
		failures.append("BUG-35 regression: live Pinball steps can pay an accumulated award before the single completion settlement.")
	var feature_source := FileAccess.get_file_as_string("res://scripts/games/slots/pinball/pinball_feature.gd")
	if not feature_source.contains("var launched := clampi(int(sim.balls_launched)"):
		failures.append("BUG-35 regression: zero-copy Pinball live status does not derive drained-ball completion from the runtime simulator.")


static func _check_bug36_craps_refund_funding_wallet(failures: Array) -> void:
	var game := CrapsGameScript.new()
	for case_value in [
		{"label": "cash-funded casino", "street": false, "funding": {"cash": 5, "chips": 0}, "bankroll": 95, "chips": 0, "expected_bankroll": 100, "expected_chips": 0},
		{"label": "chip-funded casino", "street": false, "funding": {"cash": 0, "chips": 5}, "bankroll": 100, "chips": 0, "expected_bankroll": 100, "expected_chips": 5},
		{"label": "street cash", "street": true, "funding": {"cash": 5, "chips": 0}, "bankroll": 95, "chips": 0, "expected_bankroll": 100, "expected_chips": 0},
	]:
		var case_data: Dictionary = case_value
		var run_state = RunStateScript.new()
		run_state.start_new("PLAYTEST-FIXES03-CRAPS-%s" % str(case_data.label))
		run_state.bankroll = int(case_data.bankroll)
		run_state.grand_casino_chips = int(case_data.chips)
		var table := _bug36_table(bool(case_data.street), case_data.funding)
		var environment := {
			"id": "street_craps" if bool(case_data.street) else "practice_craps",
			"archetype_id": "back_alley" if bool(case_data.street) else "grand_casino",
			"game_states": {"craps": table},
		}
		run_state.current_environment = environment
		game.call("_resolve_take_down", run_state, environment, table, "place_6", run_state.create_rng("bug36"), bool(case_data.street))
		if run_state.bankroll != int(case_data.expected_bankroll) or run_state.grand_casino_chips != int(case_data.expected_chips):
			failures.append("BUG-36 regression: %s take-down returned to the wrong wallet (cash %d, chips %d)." % [str(case_data.label), run_state.bankroll, run_state.grand_casino_chips])
	var normalized: Dictionary = game.call("_normalize_table_state", _bug36_table(false, {"cash": 3, "chips": 2}), {"id": "practice_craps", "archetype_id": "grand_casino"})
	var funding: Dictionary = normalized.get("working_bet_funding", {})
	if int((funding.get("place_6", {}) as Dictionary).get("cash", 0)) != 3 or int((funding.get("place_6", {}) as Dictionary).get("chips", 0)) != 2:
		failures.append("BUG-36 regression: Craps working-bet funding provenance does not survive normalization/save shape round-trip.")


static func _bug36_table(street: bool, funding: Dictionary) -> Dictionary:
	return {
		"schema": "craps_table_state",
		"version": 1,
		"variant_id": "street_craps" if street else "casino_craps",
		"point": 6,
		"working_bets": {
			"pass_line": 0, "dont_pass": 0, "pass_odds": 0, "dont_pass_odds": 0,
			"come": {}, "dont_come": {}, "come_odds": {}, "dont_come_odds": {},
			"place": {"6": 5}, "buy": {}, "lay": {}, "hardways": {}, "big": {},
			"working_on_come_out": false,
		},
		"working_bet_funding_version": 1,
		"working_bet_funding": {"place_6": funding.duplicate(true)},
	}
