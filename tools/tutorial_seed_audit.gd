extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const RunActionServiceScript := preload("res://scripts/core/run_action_service.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const GameModuleScript := preload("res://scripts/core/game_module.gd")
const BlackjackScript := preload("res://scripts/games/blackjack.gd")
const PullTabsScript := preload("res://scripts/games/pull_tabs.gd")

const OUTPUT_JSON := "res://.tmp/tutorial_rework/tutorial_guided_run_audit.json"
const OUTPUT_MARKDOWN := "res://.tmp/tutorial_rework/tutorial_guided_run_audit.md"

var library
var failures: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	library = ContentLibraryScript.new()
	library.load()
	for error_value in library.validation_errors:
		failures.append("Content validation: %s" % str(error_value))
	var path_a := await _run_route("path_a")
	var path_b := await _run_route("path_b_skip")
	var isolation := _normal_run_isolation()
	var report := {
		"challenge_id": "tutorial_first_card",
		"fixed_seed": str(library.challenge_config_for("tutorial_first_card", "ignored").get("seed_text", "")),
		"routes": [path_a, path_b],
		"normal_run_isolation": isolation,
		"failures": failures.duplicate(),
		"passed": failures.is_empty(),
	}
	_write_report(report)
	if failures.is_empty():
		print("TUTORIAL GUIDED RUN AUDIT PASS: Path A and Path B reached Bronze and ended.")
		quit(0)
	else:
		for failure in failures:
			push_error(str(failure))
		quit(1)


func _run_route(route_id: String) -> Dictionary:
	var route_failures: Array = []
	var config: Dictionary = library.challenge_config_for("tutorial_first_card", "IGNORED-BY-FIXED-SEED")
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(str(config.get("seed_text", "")), config)
	run_state.begin_act(1)
	var generator := RunGeneratorScript.new(library)
	generator.next_environment(run_state)
	_check(str(run_state.current_environment.get("archetype_id", "")) == "apartment", "%s did not start in the apartment." % route_id, route_failures)
	_check(run_state.bankroll == 80, "%s did not start with $80." % route_id, route_failures)
	var apartment_offers := _dict_array(run_state.current_environment.get("item_offers", []))
	_check(apartment_offers.size() == 1 and str(apartment_offers[0].get("id", "")) == "xray_glasses", "%s apartment did not contain only the forced X-ray Glasses pickup." % route_id, route_failures)
	var action_service := RunActionServiceScript.new()
	action_service.setup(library, run_state)
	var xray_pickup: Dictionary = action_service.buy_item_offer("xray_glasses")
	_check(bool(xray_pickup.get("ok", false)) and run_state.inventory.has("xray_glasses"), "%s could not pick up the X-ray Glasses through RunActionService." % route_id, route_failures)

	run_state.narrative_flags["tutorial_lessons_completed"] = {
		"tutorial_apartment_xray": true,
		"tutorial_inventory_xray": true,
	}
	run_state.enqueue_dialogue("tutorial_pal_guidance", "tutorial_guide:tutorial_open_map_corner", {"name": "Pal"}, "map_corner", "dialogue", {"tutorial_lesson_id": "tutorial_open_map_corner"})
	var restored: RunState = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	var restored_lessons: Dictionary = restored.narrative_flags.get("tutorial_lessons_completed", {}) if typeof(restored.narrative_flags.get("tutorial_lessons_completed", {})) == TYPE_DICTIONARY else {}
	var restored_talk := restored.pending_talk_event("tutorial_guide:tutorial_open_map_corner")
	_check(bool(restored_lessons.get("tutorial_inventory_xray", false)) and str(restored_talk.get("current_node", "")) == "map_corner", "%s did not restore the active Pal step across save/load." % route_id, route_failures)
	run_state.complete_talk_event_resolution("tutorial_guide:tutorial_open_map_corner")

	generator.next_environment(run_state, "corner_store", true)
	action_service.setup(library, run_state)
	var store_offers := _dict_array(run_state.current_environment.get("item_offers", []))
	var store_offer_ids := _ids(store_offers)
	_check(store_offer_ids.has("instant_coffee") and store_offer_ids.has("ledger_pencil") and store_offer_ids.size() == 2, "%s corner store did not expose both inspectable tutorial items." % route_id, route_failures)
	var store_purchase: Dictionary = action_service.buy_item_offer(str(store_offers[0].get("id", ""))) if not store_offers.is_empty() else {}
	_check(bool(store_purchase.get("ok", false)), "%s could not buy a real corner-store item." % route_id, route_failures)
	var lender_ids := _string_array(run_state.current_environment.get("lender_ids", run_state.current_environment.get("lender_hooks", [])))
	_check(lender_ids.has("the_crew"), "%s corner store did not contain The Crew." % route_id, route_failures)
	var phone_result := _resolve_event(run_state, "call_brother_in_law", "make_call")
	var family_result := _resolve_event(run_state, "family_loan", "accept")
	_check(bool(phone_result.get("ok", false)) and bool(family_result.get("ok", false)) and not run_state.debt.is_empty(), "%s did not take the real family loan and receive debt." % route_id, route_failures)
	var tip_result := _resolve_event(run_state, "parking_lot_tip", "follow_tip")
	_check(bool(tip_result.get("ok", false)) and bool(run_state.narrative_flags.get("underground_tip", false)), "%s parking tip did not open the underground route." % route_id, route_failures)

	var pull_tab_proof := {"skipped": route_id != "path_a"}
	if route_id == "path_a":
		generator.next_environment(run_state, "gas_station_casino", true)
		pull_tab_proof = _play_scripted_pull_tab(run_state, route_failures)
		generator.next_environment(run_state, "small_underground_casino", true)
	else:
		generator.next_environment(run_state, "small_underground_casino", true)
	_check(str(run_state.current_environment.get("archetype_id", "")) == "small_underground_casino", "%s did not reach Path B." % route_id, route_failures)
	var blackjack_proof := await _play_tutorial_blackjack(run_state, route_failures)
	var invite_result := _resolve_event(run_state, "tutorial_grand_casino_invitation", "accept_first_invitation")
	_check(bool(invite_result.get("ok", false)) and bool(run_state.narrative_flags.get("grand_casino_invite", false)), "%s could not accept the real high-roller invitation." % route_id, route_failures)

	generator.next_environment(run_state, "grand_casino", true)
	_check(str(run_state.current_environment.get("archetype_id", "")) == RunState.GRAND_CASINO_ARCHETYPE_ID, "%s did not reach the Grand Casino." % route_id, route_failures)
	var comp_result := _resolve_event(run_state, "comped_suite_offer", "take_comp")
	_check(bool(comp_result.get("ok", false)) and bool(run_state.narrative_flags.get("grand_casino_event_comped_suite_offer_take_comp", false)), "%s did not take the forced real comp." % route_id, route_failures)
	var cage_entered: bool = generator.enter_grand_casino_room(run_state, RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID)
	_check(cage_entered, "%s could not enter Linda's Cage." % route_id, route_failures)
	var chip_purchase := run_state.buy_grand_casino_chips(10)
	_check(bool(chip_purchase.get("ok", false)) and run_state.grand_casino_chips >= 10, "%s could not buy chips from Linda." % route_id, route_failures)
	var linda_nodes: Dictionary = _dict(library.dialogue("linda_cage_services").get("nodes", {}))
	_check(str(_dict(linda_nodes.get("main", {})).get("tutorial_text", "")).contains("Cash buys chips") and str(_dict(linda_nodes.get("chips", {})).get("tutorial_text", "")).contains("pays debt first"), "%s Linda conversation did not expose the extended tutorial chip/debt explanation." % route_id, route_failures)
	var main_entered: bool = generator.enter_grand_casino_room(run_state, RunState.GRAND_CASINO_ARCHETYPE_ID)
	_check(main_entered, "%s could not return to the Main Floor." % route_id, route_failures)
	var grand_hand := _settle_grand_blackjack_hand(run_state, route_failures)
	var ready_status := run_state.demo_objective_status()
	_check(int(ready_status.get("grand_casino_games_played", 0)) >= 1 and bool(ready_status.get("players_card_ready_to_claim", false)), "%s did not reach the compressed Bronze review after real table play: %s" % [route_id, JSON.stringify(ready_status)], route_failures)
	_check(generator.enter_grand_casino_room(run_state, RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID), "%s could not return to Linda after table play." % route_id, route_failures)
	var bronze_claim := run_state.claim_grand_casino_players_card_tier()
	_check(bool(bronze_claim.get("ok", false)) and str(bronze_claim.get("tier", "")) == RunState.GRAND_CASINO_PLAYERS_CARD_TIER_BRONZE, "%s Linda review did not issue Bronze." % route_id, route_failures)
	run_state.apply_demo_finale_result({"event_id": "tutorial_bronze_complete", "route": "tutorial_bronze_card", "branch": "win", "message": "Tutorial card issued."})
	_check(run_state.run_status == RunState.RUN_STATUS_ENDED and str(run_state.narrative_flags.get("demo_victory_route", "")) == "tutorial_bronze_card", "%s did not end at the Bronze handoff." % route_id, route_failures)
	for message in route_failures:
		failures.append(message)
	return {
		"route": route_id,
		"passed": route_failures.is_empty(),
		"apartment": {"archetype": "apartment", "xray_picked_up": run_state.inventory.has("xray_glasses")},
		"corner_store": {"offers": store_offer_ids, "family_debt_count": run_state.debt.size(), "tip_followed": bool(run_state.narrative_flags.get("underground_tip", false))},
		"pull_tabs": pull_tab_proof,
		"blackjack": blackjack_proof,
		"grand_casino": {"comp_taken": bool(run_state.narrative_flags.get("grand_casino_event_comped_suite_offer_take_comp", false)), "chips_bought": int(chip_purchase.get("chips_delta", 0)), "hand": grand_hand, "bronze_claim": bronze_claim},
		"save_load_step": str(restored_talk.get("current_node", "")),
		"tutorial_end_route": str(run_state.narrative_flags.get("demo_victory_route", "")),
	}


func _play_scripted_pull_tab(run_state: RunState, route_failures: Array) -> Dictionary:
	var game: GameModule = PullTabsScript.new()
	game.setup(library.game("pull_tabs"), library)
	game.enter(run_state, run_state.current_environment)
	var opening := game.surface_state(run_state, run_state.current_environment, {})
	var item_state: Dictionary = opening.get("pull_tab_item_state", {}) if typeof(opening.get("pull_tab_item_state", {})) == TYPE_DICTIONARY else {}
	var target: Dictionary = item_state.get("xray_target", {}) if typeof(item_state.get("xray_target", {})) == TYPE_DICTIONARY else {}
	var deal_index := int(target.get("deal_index", -1))
	var tickets_until := int(target.get("tickets_until", 0))
	_check(deal_index == 0 and int(target.get("offset", -1)) == 2 and int(target.get("payout", 0)) > 0, "Path A X-ray target was not the scripted near-bottom winner.", route_failures)
	var bought_results: Array = []
	for buy_index in range(tickets_until):
		var command := game.surface_action_command("pull_tab_buy", deal_index, false, {}, run_state, run_state.current_environment)
		var result := game.resolve_with_context(str(command.get("action_id", "")), int(command.get("set_stake", 1)), run_state, run_state.current_environment, run_state.create_rng("tutorial_pull_%d" % buy_index), command.get("ui_state", {}))
		bought_results.append({"ticket_number": result.get("pull_tab_ticket_number", ""), "payout": int(result.get("pull_tab_payout", 0)), "xray_target_consumed": bool(result.get("pull_tab_xray_target_consumed", result.get("xray_target_consumed", false)))})
	var after_buy := game.coach_state(run_state, run_state.current_environment, {})
	_check(bool(after_buy.get("scripted_target_consumed", false)), "Path A did not buy through the X-ray-marked winner.", route_failures)
	var ui_state: Dictionary = game.surface_action_command("pull_tab_collect_tray", 0, false, {}, run_state, run_state.current_environment).get("ui_state", {})
	while int(game.surface_state(run_state, run_state.current_environment, ui_state).get("pull_tab_stack_count", 0)) > 0:
		var reveal := game.surface_action_command("pull_tab_reveal_next", 0, false, ui_state, run_state, run_state.current_environment)
		ui_state = reveal.get("ui_state", {})
		var file_command := game.surface_action_command("pull_tab_file_ticket", 0, false, ui_state, run_state, run_state.current_environment)
		ui_state = file_command.get("ui_state", {})
		var sort_result := game.resolve_with_context(str(file_command.get("action_id", "")), 0, run_state, run_state.current_environment, run_state.create_rng("tutorial_pull_sort"), ui_state)
		if not bool(sort_result.get("ok", false)):
			break
	var before_redeem := run_state.bankroll
	var redeem_command := game.environment_action_command("ticket_redeemer", "redeem_pull_tab_winners", run_state, run_state.current_environment, run_state.create_rng("tutorial_pull_redeem"))
	var redeem_result: Dictionary = redeem_command.get("result", {}) if typeof(redeem_command.get("result", {})) == TYPE_DICTIONARY else {}
	if bool(redeem_result.get("ok", false)):
		GameModuleScript.apply_result(run_state, redeem_result, run_state.create_rng("tutorial_pull_redeem_apply"))
	_check(int(redeem_result.get("pull_tab_redeemed_payout", 0)) > 0 and run_state.bankroll > before_redeem, "Path A winner did not pay at the real clerk.", route_failures)
	return {"skipped": false, "xray_target": target, "tickets_bought": bought_results, "redeemed_payout": int(redeem_result.get("pull_tab_redeemed_payout", 0))}


func _play_tutorial_blackjack(run_state: RunState, route_failures: Array) -> Dictionary:
	var game: GameModule = BlackjackScript.new()
	game.setup(library.game("blackjack"), library)
	game.enter(run_state, run_state.current_environment)
	var clean := _deal_and_stand(game, run_state, 2, "tutorial_clean")
	_check(bool(clean.get("settled", false)), "Tutorial blackjack normal hand did not settle.", route_failures)
	var deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 4}, run_state, run_state.current_environment)
	var deal_result := game.resolve_with_context(str(deal.get("action_id", "blackjack_place_bet")), 4, run_state, run_state.current_environment, run_state.create_rng("tutorial_raised_deal"), deal.get("ui_state", {}))
	var hand_state: Dictionary = deal.get("ui_state", {})
	var distraction := game.surface_action_command("blackjack_distraction", 0, false, hand_state, run_state, run_state.current_environment)
	var distracted_state: Dictionary = distraction.get("ui_state", {})
	var peek := game.surface_action_command("blackjack_peek", 0, true, distracted_state, run_state, run_state.current_environment)
	var peek_state: Dictionary = peek.get("ui_state", {})
	var peek_result := game.resolve_with_context("peek_hole_card", 0, run_state, run_state.current_environment, run_state.create_rng("tutorial_peek"), peek_state)
	_check(bool(peek_state.get("peek_had_window", false)) and bool(peek_state.get("dealer_hole_visible", false)) and bool(peek_result.get("ok", false)), "Tutorial peek did not use the real distraction lookaway window.", route_failures)
	var count_start := game.surface_action_command("blackjack_count", 0, false, peek_state, run_state, run_state.current_environment)
	var count_state: Dictionary = count_start.get("ui_state", {})
	var challenge: Dictionary = count_state.get("count_challenge", {}) if typeof(count_state.get("count_challenge", {})) == TYPE_DICTIONARY else {}
	var icons := _dict_array(challenge.get("icons", []))
	var now := Time.get_ticks_msec()
	for icon_index in range(icons.size()):
		var icon: Dictionary = icons[icon_index]
		icon["spawn_msec"] = now - 1
		icon["duration_msec"] = 5000
		icons[icon_index] = icon
	challenge["icons"] = icons
	count_state["count_challenge"] = challenge
	for icon_index in range(icons.size()):
		count_state = game.surface_action_command("blackjack_count_icon", icon_index, false, count_state, run_state, run_state.current_environment).get("ui_state", {})
	var coach_state := game.coach_state(run_state, run_state.current_environment, count_state)
	_check(not icons.is_empty() and bool(coach_state.get("count_all_selected", false)), "Tutorial count did not select every real count pulse.", route_failures)
	var count_result := game.resolve_with_context("count_cards", 0, run_state, run_state.current_environment, run_state.create_rng("tutorial_count"), count_state)
	var final_count_state: Dictionary = count_result.get("blackjack_surface_ui_state", count_state) if typeof(count_result.get("blackjack_surface_ui_state", count_state)) == TYPE_DICTIONARY else count_state
	_check(bool(count_result.get("blackjack_count_answered", false)), "Tutorial count did not finalize through the real count action.", route_failures)
	var stand := game.surface_action_command("blackjack_stand", 0, false, final_count_state, run_state, run_state.current_environment)
	if bool(stand.get("resolve", false)):
		game.resolve_with_context(str(stand.get("action_id", "play_basic")), 4, run_state, run_state.current_environment, run_state.create_rng("tutorial_raised_stand"), stand.get("ui_state", {}))
	return {"normal_hand_settled": bool(clean.get("settled", false)), "raised_bet": 4, "lookaway_id": str(distracted_state.get("dealer_lookaway_id", "")), "peek_had_window": bool(peek_state.get("peek_had_window", false)), "count_icon_count": icons.size(), "count_all_selected": bool(coach_state.get("count_all_selected", false)), "count_heat_delta": int(count_result.get("suspicion_delta", 0)), "raised_deal_ok": bool(deal_result.get("ok", false))}


func _deal_and_stand(game: GameModule, run_state: RunState, stake: int, rng_label: String) -> Dictionary:
	var deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": stake}, run_state, run_state.current_environment)
	var deal_result := game.resolve_with_context(str(deal.get("action_id", "blackjack_place_bet")), stake, run_state, run_state.current_environment, run_state.create_rng("%s_deal" % rng_label), deal.get("ui_state", {}))
	var stand := game.surface_action_command("blackjack_stand", 0, false, deal.get("ui_state", {}), run_state, run_state.current_environment)
	var stand_result := {}
	if bool(stand.get("resolve", false)):
		stand_result = game.resolve_with_context(str(stand.get("action_id", "play_basic")), stake, run_state, run_state.current_environment, run_state.create_rng("%s_stand" % rng_label), stand.get("ui_state", {}))
	return {"deal_ok": bool(deal_result.get("ok", false)), "settled": bool(stand_result.get("ok", false)), "result": stand_result}


func _settle_grand_blackjack_hand(run_state: RunState, route_failures: Array) -> Dictionary:
	var game: GameModule = BlackjackScript.new()
	game.setup(library.game("blackjack"), library)
	game.enter(run_state, run_state.current_environment)
	var hand := _deal_and_stand(game, run_state, 1, "tutorial_grand")
	_check(bool(hand.get("settled", false)), "Grand Casino tutorial table hand did not settle through Blackjack.", route_failures)
	return hand


func _normal_run_isolation() -> Dictionary:
	var config: Dictionary = library.challenge_config_for("standard", "NORMAL-ISOLATION")
	var modifiers: Dictionary = config.get("modifiers", {}) if typeof(config.get("modifiers", {})) == TYPE_DICTIONARY else {}
	var grand: Dictionary = library.environment_archetype(RunState.GRAND_CASINO_ARCHETYPE_ID)
	var objective: Dictionary = grand.get("demo_objective", {}) if typeof(grand.get("demo_objective", {})) == TYPE_DICTIONARY else {}
	var phone: Dictionary = library.event("call_brother_in_law")
	var phone_choices := _dict_array(_dict(phone.get("payload", {})).get("choices", []))
	var normal_chain_chance := -1.0
	for choice in phone_choices:
		if str(choice.get("id", "")) == "make_call":
			normal_chain_chance = float(_dict(_dict(choice.get("consequences", {})).get("trigger_event", {})).get("chance", -1.0))
	var normal_run: RunState = RunStateScript.new()
	normal_run.start_new("NORMAL-PULL-TAB-ISOLATION", config)
	var normal_environment := {"id": "normal_pull_tabs", "archetype_id": "gas_station_casino", "game_states": {}, "economic_profile": {"stake_floor": 1, "stake_ceiling": 100}}
	var pull_tabs: GameModule = PullTabsScript.new()
	pull_tabs.setup(library.game("pull_tabs"), library)
	var normal_machine := pull_tabs.generate_environment_state(normal_run, normal_environment, normal_run.create_rng("normal_stock"))
	var scripted := false
	for deal in _dict_array(normal_machine.get("deals", [])):
		if bool(deal.get("tutorial_xray_scripted", false)):
			scripted = true
	_check(not modifiers.has("tutorial_forced_event_choices") and not modifiers.has("tutorial_pull_tab_xray_offset"), "Tutorial forcing leaked into a normal challenge config.", failures)
	_check(normal_chain_chance == 0.75, "Normal family phone chance changed from 0.75.", failures)
	_check(not scripted, "Tutorial X-ray stock scripting leaked into a normal pull-tab machine.", failures)
	_check(int(objective.get("high_roller_net_winnings", -1)) == 30 and int(objective.get("high_roller_min_grand_casino_games", -1)) == 5 and int(objective.get("high_roller_max_heat", -1)) == 30, "Normal Grand Casino thresholds changed.", failures)
	var host_dialogue: Dictionary = library.dialogue("normal_grand_host_greeting")
	_check(str(_dict(host_dialogue.get("speaker", {})).get("character_id", "")) == "vivienne_grand_host", "Normal-run Host greeting is missing Vivienne.", failures)
	return {"tutorial_modifier_keys_absent": not modifiers.has("tutorial_forced_event_choices"), "family_phone_chain_chance": normal_chain_chance, "pull_tab_stock_scripted": scripted, "grand_thresholds": {"net": objective.get("high_roller_net_winnings", -1), "games": objective.get("high_roller_min_grand_casino_games", -1), "heat": objective.get("high_roller_max_heat", -1)}, "host_greeting_dialogue": str(host_dialogue.get("id", ""))}


func _resolve_event(run_state: RunState, event_id: String, choice_id: String) -> Dictionary:
	var event_module := EventModuleScript.new()
	event_module.setup(library.event(event_id), library)
	return event_module.resolve(run_state, run_state.current_environment, choice_id)


func _check(condition: bool, message: String, target_failures: Array) -> void:
	if not condition and not message.is_empty():
		target_failures.append(message)


func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


func _dict_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value as Array:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append((entry as Dictionary).duplicate(true))
	return result


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for entry in value as Array:
			result.append(str(entry))
	return result


func _ids(values: Array) -> Array:
	var result: Array = []
	for value in values:
		if typeof(value) == TYPE_DICTIONARY:
			result.append(str((value as Dictionary).get("id", "")))
	return result


func _write_report(report: Dictionary) -> void:
	var absolute_json := ProjectSettings.globalize_path(OUTPUT_JSON)
	DirAccess.make_dir_recursive_absolute(absolute_json.get_base_dir())
	var json_file := FileAccess.open(OUTPUT_JSON, FileAccess.WRITE)
	json_file.store_string(JSON.stringify(report, "\t"))
	json_file.close()
	var lines := [
		"# Dialogue-guided tutorial route audit",
		"",
		"- Fixed seed: `%s`" % str(report.get("fixed_seed", "")),
		"- Result: **%s**" % ("PASS" if bool(report.get("passed", false)) else "FAIL"),
	]
	for route_value in report.get("routes", []):
		var route: Dictionary = route_value
		lines.append("- `%s`: %s; end `%s`; X-ray payout `$%d`; count pulses `%d`." % [str(route.get("route", "")), "PASS" if bool(route.get("passed", false)) else "FAIL", str(route.get("tutorial_end_route", "")), int(_dict(route.get("pull_tabs", {})).get("redeemed_payout", 0)), int(_dict(route.get("blackjack", {})).get("count_icon_count", 0))])
	lines.append("- Normal isolation: `%s`" % JSON.stringify(report.get("normal_run_isolation", {})))
	if not report.get("failures", []).is_empty():
		lines.append("")
		lines.append("## Failures")
		for failure in report.get("failures", []):
			lines.append("- %s" % str(failure))
	var markdown_file := FileAccess.open(OUTPUT_MARKDOWN, FileAccess.WRITE)
	markdown_file.store_string("\n".join(lines) + "\n")
	markdown_file.close()
