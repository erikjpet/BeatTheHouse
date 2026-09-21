class_name PlaytestFixes02Contract
extends RefCounted

const BaccaratGameScript := preload("res://scripts/games/baccarat.gd")
const BarDiceGameScript := preload("res://scripts/games/bar_dice.gd")
const BlackjackGameScript := preload("res://scripts/games/blackjack.gd")
const EnvironmentInteractionViewModelScript := preload("res://scripts/ui/environment_interaction_view_model.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const FoundationMainScript := preload("res://scripts/ui/foundation_main.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const RouletteGameScript := preload("res://scripts/games/roulette.gd")
const RunActionServiceScript := preload("res://scripts/core/run_action_service.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const TalkDockScript := preload("res://scripts/ui/talk_dock.gd")


static func check(library, failures: Array) -> void:
	_check_bug24_baccarat_back_geometry(failures)
	_check_bug25_inline_action_detail_geometry(failures)
	_check_bug26_scenario_instruction_deduplication(failures)
	_check_bug27_blackjack_semantic_round_result(failures)
	_check_bug28_bar_dice_guidance_geometry(failures)
	_check_bug29_roulette_rebet_authority(failures)
	_check_bug30_chained_speaker_hydration(library, failures)
	_check_bug31_lender_term_disclosure(library, failures)


static func _check_bug24_baccarat_back_geometry(failures: Array) -> void:
	var source := FileAccess.get_file_as_string("res://scripts/games/baccarat.gd")
	if not source.contains("BACCARAT_EXPLAINER_RECT") or not source.contains("BACCARAT_SURFACE_BACK_RECT"):
		failures.append("BUG-24 regression: Baccarat does not publish named explainer/back geometry.")
		return
	var game := BaccaratGameScript.new()
	var layout: Dictionary = game.call("baccarat_overlay_layout_snapshot")
	var back_rect: Rect2 = layout.get("surface_back_rect", Rect2())
	var explainer_rect: Rect2 = layout.get("explainer_rect", Rect2())
	if back_rect.size.x <= 0.0 or explainer_rect.size.x <= 0.0 or back_rect.intersects(explainer_rect):
		failures.append("BUG-24 regression: Baccarat LEAVE geometry overlaps the hand explainer (%s vs %s)." % [back_rect, explainer_rect])


static func _check_bug25_inline_action_detail_geometry(failures: Array) -> void:
	var canvas := PixelSceneCanvasScript.new()
	canvas.selected_object_id = "dave_warning"
	var details := [
		"Dave remembers this answer.",
		"Dave notices the ignored warning, remembers the slight, changes the next encounter, and adds heat if the player walks away.",
		"Ignoring Dave changes his later route, marks the relationship, raises pressure at the next meeting, and leaves a longer consequence explanation that must remain legible even on the compact selected-object card.",
	]
	for detail_value in details:
		var object_data := {
			"id": "dave_warning",
			"inline_actions": [{"id": "dave_answer", "emit_object_id": "dave_answer", "label": "Answer Dave", "text": str(detail_value)}],
		}
		var height := float(canvas.call("_selected_info_action_area_height", object_data))
		var card := Rect2(40, 40, 300, 180)
		var entries: Array = canvas.call("_selected_info_action_entries_for_rect", {"object": object_data}, card)
		if str(detail_value).length() > 80 and height <= 30.0 or entries.is_empty():
			failures.append("BUG-25 regression: long inline-action consequence copy still receives the fixed one-line detail height.")
		elif typeof(entries[0]) == TYPE_DICTIONARY:
			var detail_rect: Rect2 = (entries[0] as Dictionary).get("detail_rect", Rect2())
			if detail_rect.size.y <= 0.0 or detail_rect.end.y > card.end.y + 0.01:
				failures.append("BUG-25 regression: wrapped inline-action detail does not remain inside the selected-object card.")
	canvas.small_screen_mode = true
	var compact_data := {"id": "dave_warning", "inline_actions": [{"id": "dave_answer", "emit_object_id": "dave_answer", "label": "Answer Dave", "text": str(details[2])}]}
	var compact_entries: Array = canvas.call("_selected_info_action_entries_for_rect", {"object": compact_data}, Rect2(8, 8, 276, 196))
	if compact_entries.is_empty() or ((compact_entries[0] as Dictionary).get("detail_rect", Rect2()) as Rect2).end.y > 204.01:
		failures.append("BUG-25 regression: compact inline-action consequence geometry escapes its card.")
	canvas.free()


static func _check_bug26_scenario_instruction_deduplication(failures: Array) -> void:
	var repeated := "Choose the marked envelope before the timer closes."
	var scenario := EnvironmentInteractionViewModelScript.make_interactable_object({
		"object_id": "scenario:test",
		"object_type": "scenario",
		"scenario_owner_namespace": "scenario:test",
		"short_description": repeated,
		"action_summary": "  choose   the marked envelope before the timer closes.  ",
		"focus_rect": {"x": 0, "y": 0, "w": 100, "h": 80},
	}, {})
	if not str(scenario.get("action_summary", "")).is_empty():
		failures.append("BUG-26 regression: equivalent scenario instruction text is projected into both description and action summary.")
	var production_records: Array = EnvironmentInteractionViewModelScript.deduplicated_scenario_instruction_records([{
		"object_id": "scenario::goods_lot",
		"object_type": "scenario_sequence",
		"owner_namespace": "scenario",
		"short_description": repeated,
		"action_summary": repeated,
		"focus_rect": {"x": 0, "y": 0, "w": 100, "h": 80},
	}])
	var production_sequence: Dictionary = production_records[0] if not production_records.is_empty() else {}
	if not str(production_sequence.get("action_summary", "")).is_empty():
		failures.append("BUG-26 regression: the production scenario_sequence projection bypasses instruction de-duplication.")
	var distinct := EnvironmentInteractionViewModelScript.make_interactable_object({
		"object_id": "scenario:distinct",
		"object_type": "scenario",
		"scenario_owner_namespace": "scenario:test",
		"short_description": "A sealed envelope waits.",
		"action_summary": "Choose the marked envelope.",
		"focus_rect": {"x": 0, "y": 0, "w": 100, "h": 80},
	}, {})
	if str(distinct.get("action_summary", "")).is_empty():
		failures.append("BUG-26 regression: distinct scenario action instructions are suppressed with duplicate copy.")


static func _check_bug27_blackjack_semantic_round_result(failures: Array) -> void:
	var game := BlackjackGameScript.new()
	var cases := [
		{"name": "loss", "main": -11, "side": 0, "transfer": 0, "headline": "HOUSE TAKES", "round": -11},
		{"name": "win", "main": 11, "side": 0, "transfer": 22, "headline": "PLAYER PAID", "round": 11},
		{"name": "push", "main": 0, "side": 0, "transfer": 11, "headline": "PUSH", "round": 0},
		{"name": "surrender", "main": -5, "side": 0, "transfer": 6, "headline": "HOUSE TAKES", "round": -5},
		{"name": "split net push", "main": 0, "side": 0, "transfer": 22, "headline": "PUSH", "round": 0},
		{"name": "side win", "main": -11, "side": 25, "transfer": 25, "headline": "PLAYER PAID", "round": 14},
		{"name": "side loss", "main": 11, "side": -5, "transfer": 17, "headline": "PLAYER PAID", "round": 6},
	]
	for case_value in cases:
		var case_data: Dictionary = case_value
		var result: Dictionary = game.call("_blackjack_last_result_payload", FunctionOptions.BlackjackResultOptions.from({
			"message": case_data.name, "hand_results": [], "side_results": [], "main_delta": case_data.main,
			"side_delta": case_data.side, "bankroll_delta": case_data.transfer, "suspicion_delta": 0,
			"dealer_cards": [], "player_hands": [], "patron_hands": [], "patron_action_events": [],
			"cheat": {}, "result_msec": 10,
		}))
		if int(result.get("round_net_delta", 999999)) != int(case_data.round) or str(result.get("headline", "")) != str(case_data.headline):
			failures.append("BUG-27 regression: %s uses settlement transfer instead of semantic round net (%s)." % [case_data.name, result])
		if int(result.get("outcome_bankroll_delta", result.get("round_net_delta", 999999))) != int(case_data.round):
			failures.append("BUG-27 regression: %s does not publish its semantic delta to shared result presentation." % case_data.name)
	var caught: Dictionary = game.call("_blackjack_last_result_payload", FunctionOptions.BlackjackResultOptions.from({
		"message": "caught", "hand_results": [], "side_results": [], "main_delta": 11, "side_delta": 0,
		"bankroll_delta": -14, "suspicion_delta": 8, "dealer_cards": [], "player_hands": [],
		"patron_hands": [], "patron_action_events": [], "cheat": {"caught": true},
		"result_msec": 11, "round_net_delta_value": -25,
	}))
	if int(caught.get("round_net_delta", 0)) != -25 or str(caught.get("headline", "")) != "HEAT SPIKE":
		failures.append("BUG-27 regression: caught-cheat penalty is absent from the semantic round result.")
	var save_run = RunStateScript.new()
	save_run.start_new("PLAYTEST-FIXES02-BLACKJACK-SAVE")
	save_run.current_environment = {"id": "blackjack_save", "archetype_id": "casino", "game_states": {"blackjack": {"last_result": caught}}}
	var loaded_run = RunStateScript.new()
	loaded_run.from_dict(save_run.to_dict())
	var loaded_result: Dictionary = ((loaded_run.current_environment.get("game_states", {}) as Dictionary).get("blackjack", {}) as Dictionary).get("last_result", {})
	if int(loaded_result.get("round_net_delta", 0)) != -25:
		failures.append("BUG-27 regression: semantic Blackjack result does not survive save/Continue serialization.")


static func _check_bug28_bar_dice_guidance_geometry(failures: Array) -> void:
	var source := FileAccess.get_file_as_string("res://scripts/games/bar_dice.gd")
	var start := source.find("func _draw_console")
	var finish := source.find("\nfunc ", start + 8)
	var draw_console := source.substr(start, finish - start) if start >= 0 and finish > start else ""
	var game := BarDiceGameScript.new()
	var layout: Dictionary = game.call("_bar_dice_layout_snapshot")
	var guidance_rect: Rect2 = layout.get("guidance_rect", Rect2())
	if draw_console.contains("prompt.left(74)") or not draw_console.contains("surface_label_centered") or guidance_rect.size.x < 300.0 or guidance_rect.end.x > 900.0:
		failures.append("BUG-28 regression: Bar Dice guidance is truncated by character count instead of fitting a bounded console rect.")


static func _check_bug29_roulette_rebet_authority(failures: Array) -> void:
	var game := RouletteGameScript.new()
	var previous := [{"id": "straight:17", "kind": "straight", "label": "17", "numbers": ["17"], "stake": 5}]
	var session: Dictionary = game.call("_normalized_session", null, {}, {"roulette_rebet": []}, {"last_bets": previous})
	if (session.get("roulette_rebet", []) as Array).is_empty():
		failures.append("BUG-29 regression: an explicitly empty transient Roulette rebet list shadows authoritative table.last_bets.")
	else:
		var run_state = RunStateScript.new()
		run_state.start_new("PLAYTEST-FIXES02-ROULETTE-REBET")
		run_state.bankroll = 100
		var command: Dictionary = game.call("_rebet_command", session, {"last_bets": previous, "table_maximum": 500}, run_state, {"id": "roulette_room", "archetype_id": "casino"})
		if not bool(command.get("handled", false)) or ((command.get("ui_state", {}) as Dictionary).get("roulette_bets", []) as Array).is_empty():
			failures.append("BUG-29 regression: spin -> clear -> rebet cannot restore the authoritative settled layout.")


static func _check_bug30_chained_speaker_hydration(library, failures: Array) -> void:
	var run_state = RunStateScript.new()
	run_state.start_new("PLAYTEST-FIXES02-CHAIN-SPEAKER")
	run_state.current_environment = {"id": "chain_room", "archetype_id": "motel", "kind": "shop", "turns": 0}
	var module := EventModuleScript.new()
	module.setup({}, library)
	module.call("_apply_trigger_event_hook", run_state, {"event_id": "source", "choice_id": "call"}, {
		"event_id": "family_loan",
		"chance": 1.0,
		"entry_overrides": {"presentation": "talk", "speaker": {"mood": "urgent"}},
	})
	var queued: Dictionary = run_state.pending_talk_event("family_loan")
	var speaker: Dictionary = queued.get("speaker", {})
	if str(speaker.get("name", "")) != "Unknown Caller" or str(speaker.get("presentation", "")) != "faceless_silhouette" or str(speaker.get("speaking_character_name", "")).is_empty() or str(speaker.get("mood", "")) != "urgent":
		failures.append("BUG-30 regression: chained event speaker defaults, roster metadata, or explicit hook overrides were not merged (%s)." % speaker)
	var loaded_run = RunStateScript.new()
	loaded_run.from_dict(run_state.to_dict())
	var loaded_speaker: Dictionary = loaded_run.pending_talk_event("family_loan").get("speaker", {})
	if str(loaded_speaker.get("name", "")) != "Unknown Caller" or str(loaded_speaker.get("speaking_character_name", "")).is_empty():
		failures.append("BUG-30 regression: chained speaker identity does not survive save/Continue.")
	var dock := TalkDockScript.new()
	dock.entry = queued
	if not str(dock.call("_speaker_display_name")).contains("Gabe Mercer"):
		failures.append("BUG-30 regression: the rendered nameplate does not expose the hydrated speaker identity.")
	dock.entry = {"speaker": {"presentation": "faceless_silhouette", "name": ""}}
	if str(dock.call("_speaker_display_name")) != "Unknown":
		failures.append("BUG-30 regression: unnamed faceless speaker does not use the generic Unknown fallback.")
	dock.free()


static func _check_bug31_lender_term_disclosure(library, failures: Array) -> void:
	var run_state = RunStateScript.new()
	run_state.start_new("PLAYTEST-FIXES02-LENDER-TERMS")
	run_state.current_environment = {"id": "lender_room", "archetype_id": "motel", "kind": "shop", "turns": 0, "lender_hooks": ["street_lender", "motel_friend", "the_crew", "brother_in_law"]}
	run_state.narrative_flags["brother_in_law_phone_ready"] = true
	var service := RunActionServiceScript.new()
	service.setup(library, run_state)
	var expected := {
		"street_lender": [25, 28, 10, 3],
		"motel_friend": [20, 22, 10, 4],
		"the_crew": [45, 2, 0, 2],
		"brother_in_law": [30, 33, 10, 6],
	}
	for lender_id in expected.keys():
		var option: Dictionary = service.hook_option("lender", str(lender_id))
		var terms: Dictionary = option.get("loan_terms", {})
		var values: Array = expected[lender_id]
		if int(terms.get("principal", -1)) != int(values[0]) or int(terms.get("repayment_total", -1)) != int(values[1]) or int(terms.get("interest_percent", -1)) != int(values[2]) or int(terms.get("deadline_turns", -1)) != int(values[3]):
			failures.append("BUG-31 regression: %s does not expose exact model-derived terms (%s)." % [lender_id, terms])
		if str(option.get("summary", "")).find(str((library.lender(str(lender_id)) as Dictionary).get("description", ""))) != 0 or str(option.get("terms_summary", "")).is_empty():
			failures.append("BUG-31 regression: %s offer terms replace authored voice or remain hidden." % lender_id)
	var host := FoundationMainScript.new()
	host.library = library
	host.run_state = run_state
	var entry := {"event_id": "lender_conversation:borrow:street_lender", "context": {"type": "lender_conversation", "lender_mode": "borrow", "lender_id": "street_lender"}}
	var conversation: Dictionary = host.call("_lender_conversation_option", entry)
	var choices: Array = conversation.get("choices", [])
	var accept: Dictionary = choices[0] if not choices.is_empty() and typeof(choices[0]) == TYPE_DICTIONARY else {}
	for text_value in [conversation.get("summary", ""), accept.get("consequence_summary", "")]:
		var text := str(text_value)
		for token in ["$25", "$28", "10%", "3 turns"]:
			if not text.contains(token):
				failures.append("BUG-31 regression: Vic's offer/confirmation omits %s (%s)." % [token, text])
	host.free()
	var result: Dictionary = service.use_hook("lender", "street_lender")
	for token in ["$25", "$28", "10%", "3 turns"]:
		if not str(result.get("message", "")).contains(token):
			failures.append("BUG-31 regression: Vic's result acknowledgement omits %s (%s)." % [token, result.get("message", "")])
	var continued_run = RunStateScript.new()
	continued_run.from_dict(run_state.to_dict())
	var vic_debt: Dictionary = {}
	for debt_value in continued_run.debt:
		if typeof(debt_value) == TYPE_DICTIONARY and str((debt_value as Dictionary).get("lender_id", "")) == "street_lender":
			vic_debt = debt_value
			break
	if int(vic_debt.get("principal", 0)) != 25 or int(vic_debt.get("balance", 0)) != 28 or int(vic_debt.get("deadline_turns", 0)) != 3:
		failures.append("BUG-31 regression: disclosed Vic terms do not match the debt restored by Continue (%s)." % vic_debt)
	var family_event := EventModuleScript.new()
	family_event.setup(library.event("family_loan"), library)
	var family_choices: Array = family_event.choices(continued_run, continued_run.current_environment)
	var family_accept: Dictionary = family_choices[0] if not family_choices.is_empty() and typeof(family_choices[0]) == TYPE_DICTIONARY else {}
	for token in ["$30", "$33", "10%", "6 turns"]:
		if not str(family_accept.get("text", "")).contains(token) or not str(family_accept.get("consequence_summary", "")).contains(token):
			failures.append("BUG-31 regression: chained family-loan offer omits %s before acceptance." % token)
