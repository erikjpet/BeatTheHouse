extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const RunActionServiceScript := preload("res://scripts/core/run_action_service.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const GameModuleScript := preload("res://scripts/core/game_module.gd")
const WorldMapScript := preload("res://scripts/core/world_map.gd")
const BlackjackScript := preload("res://scripts/games/blackjack.gd")
const PullTabsScript := preload("res://scripts/games/pull_tabs.gd")
const BlackjackAuthorityTestDriverScript := preload("res://scripts/tests/foundation/blackjack_authority_test_driver.gd")

const DEFAULT_OUTPUT_DIR := "res://.tmp/tutorial_rework"

var library
var failures: Array = []
var output_dir := DEFAULT_OUTPUT_DIR


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			output_dir = argument.trim_prefix("--out=").trim_suffix("/")
	call_deferred("_run")


func _run() -> void:
	library = ContentLibraryScript.new()
	library.load()
	for error_value in library.validation_errors:
		failures.append("Content validation: %s" % str(error_value))
	var authored_contract := _verify_authored_contract()
	var path_a := await _run_route("path_a")
	var path_b := await _run_route("path_b_skip")
	var isolation := _normal_run_isolation()
	var stuck_sweep := _tutorial_stuck_sweep(100)
	var lesson_boundary_save_load := _tutorial_lesson_boundary_save_load()
	var report := {
		"challenge_id": "tutorial_first_card",
		"fixed_seed": str(library.challenge_config_for("tutorial_first_card", "ignored").get("seed_text", "")),
		"routes": [path_a, path_b],
		"authored_contract": authored_contract,
		"normal_run_isolation": isolation,
		"tutorial_stuck_sweep": stuck_sweep,
		"lesson_boundary_save_load": lesson_boundary_save_load,
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


func _verify_authored_contract() -> Dictionary:
	var ambient_ids: Array = []
	var authored_delivery_count := 0
	var highlighted_count := 0
	for lesson_value in library.tutorial_lessons:
		if typeof(lesson_value) != TYPE_DICTIONARY:
			continue
		var lesson: Dictionary = lesson_value
		var lesson_id := str(lesson.get("id", ""))
		if lesson_id.begins_with("tip_first_") or lesson_id == "tip_starter_card_home":
			ambient_ids.append(lesson_id)
		if str(lesson.get("scope", "")) == "tutorial_run":
			if ["dialogue", "coach"].has(str(lesson.get("delivery", ""))) and not str(lesson.get("dialogue_id", "")).is_empty() and not str(lesson.get("dialogue_node", "")).is_empty():
				authored_delivery_count += 1
			var anchor: Dictionary = lesson.get("anchor", {}) if typeof(lesson.get("anchor", {})) == TYPE_DICTIONARY else {}
			if str(anchor.get("kind", "none")) != "none" and not str(anchor.get("id", "")).is_empty():
				highlighted_count += 1
	_check(ambient_ids.is_empty(), "Removed ambient tutorial tips still exist: %s" % JSON.stringify(ambient_ids), failures)
	_check(authored_delivery_count == library.tutorial_lessons.size(), "Not every shipped tutorial lesson uses an authored dialogue or coach delivery.", failures)
	_check(highlighted_count == library.tutorial_lessons.size(), "Not every shipped tutorial lesson owns a highlight anchor.", failures)

	var pal: Dictionary = library.character("pal_tutorial_guide")
	var host: Dictionary = library.character("vivienne_grand_host")
	var bible_text := FileAccess.get_file_as_string("res://docs/plans/0.5_voice_bible.md")
	_check(str(pal.get("display_name", "")) == "Pal" and str(pal.get("voice", {})).contains("your pal"), "Pal is missing or does not call themselves your pal.", failures)
	_check(str(host.get("display_name", "")) == "Vivienne Vale" and str(host.get("id", "")) != "linda_cage_host", "Vivienne Vale is missing or not distinct from Linda.", failures)
	_check(bible_text.contains("Pal") and bible_text.contains("your pal") and bible_text.contains("Vivienne Vale") and bible_text.contains("Grand Casino Host"), "Voice bible is missing Pal or Vivienne Vale.", failures)

	var inspect_coffee: Dictionary = library.tutorial_lesson("tutorial_inspect_coffee")
	var inspect_pencil: Dictionary = library.tutorial_lesson("tutorial_inspect_pencil")
	var buy_item: Dictionary = library.tutorial_lesson("tutorial_buy_store_item")
	var buy_remaining_item: Dictionary = library.tutorial_lesson("tutorial_buy_remaining_store_item")
	_check(str(_dict(inspect_coffee.get("anchor", {})).get("id", "")) == "item:instant_coffee", "Corner-store first item inspection is not authored.", failures)
	_check(_string_array(_dict(inspect_pencil.get("trigger", {})).get("depends_on", [])).has("tutorial_inspect_coffee") and str(_dict(inspect_pencil.get("anchor", {})).get("id", "")) == "item:ledger_pencil", "Corner-store second item inspection does not follow the first.", failures)
	_check(_string_array(_dict(buy_item.get("trigger", {})).get("depends_on", [])).has("tutorial_inspect_pencil"), "Corner-store purchase does not wait for both inspections.", failures)
	_check(_string_array(_dict(buy_remaining_item.get("trigger", {})).get("depends_on", [])).has("tutorial_buy_store_item"), "Corner-store second purchase does not follow the first purchase.", failures)
	_check(str(_dict(buy_remaining_item.get("completion", {})).get("type", "")) == "state_predicate" and (_dict(buy_remaining_item.get("completion", {})).get("state_predicates", []) as Array).size() == 2, "Corner-store tutorial does not require both shelf items.", failures)

	var pal_nodes := _dict(library.dialogue("tutorial_pal_guidance").get("nodes", {}))
	var corner_buy_copy := str(_dict(pal_nodes.get("corner_buy_both", {})).get("text", ""))
	var route_copy := str(_dict(pal_nodes.get("route_split", {})).get("text", ""))
	var crew_copy := str(_dict(pal_nodes.get("crew_warning", {})).get("text", ""))
	var lookaway_copy := str(_dict(pal_nodes.get("blackjack_lookaway", {})).get("text", ""))
	var peek_copy := str(_dict(pal_nodes.get("blackjack_peek", {})).get("text", ""))
	var gas_peek_copy := str(_dict(pal_nodes.get("gas_peek", {})).get("text", ""))
	var gas_peek_heat_copy := str(_dict(pal_nodes.get("gas_peek_heat", {})).get("text", ""))
	var invitation_copy := str(_dict(pal_nodes.get("invitation", {})).get("text", ""))
	var goodbye_copy := str(_dict(pal_nodes.get("grand_depart", {})).get("text", ""))
	_check(route_copy.contains("tip opened two doors") and route_copy.contains("strongly recommend") and route_copy.contains("skip"), "Pal does not explain and strongly steer the skippable route split.", failures)
	_check(corner_buy_copy.contains("Buy both") and corner_buy_copy.contains("Either order"), "Pal does not explicitly require both Corner Store items in either order.", failures)
	_check(crew_copy.contains("isn't free") and crew_copy.contains("put you to work") and not crew_copy.contains("Avoid the Crew"), "Pal's Crew hint must imply the loan's work obligation without directly telling the player to avoid the Crew.", failures)
	_check(lookaway_copy.contains("easiest cheat") and lookaway_copy.contains("DRINK PASS spills a drink") and lookaway_copy.contains("CHIP SPILL"), "Pal's lookaway copy is not accurate to the real controls.", failures)
	_check(peek_copy.contains("add heat") and peek_copy.contains("close the table"), "Pal's peek copy omits caught consequences.", failures)
	_check(gas_peek_copy.contains("50%") and gas_peek_copy.contains("8%") and gas_peek_copy.contains("9%") and gas_peek_copy.contains("10%") and gas_peek_copy.contains("11%") and gas_peek_copy.contains("four times"), "Pal's pull-tab Peek copy omits its chance, escalating Heat, or required attempts.", failures)
	_check(gas_peek_heat_copy.contains("real Heat") and gas_peek_heat_copy.contains("adds no Heat") and gas_peek_heat_copy.contains("Tab Detector"), "Pal's optional pull-tab Heat review omits the owned-detector contrast.", failures)
	_check(invitation_copy.contains("keep an eye on your environment") and invitation_copy.contains("accept"), "Pal's invitation copy omits environment scanning or acceptance.", failures)
	_check(goodbye_copy.contains("banned") and goodbye_copy.contains("Rourke") and goodbye_copy.contains("Good luck"), "Pal's Grand Casino farewell is incomplete.", failures)

	var modifiers := _dict(library.challenge_config_for("tutorial_first_card", "IGNORED").get("modifiers", {}))
	var forced_choices := _dict(modifiers.get("tutorial_forced_event_choices", {}))
	_check(str(forced_choices.get("comped_suite_offer", "")) == "take_comp", "Tutorial comp is not forced to take_comp.", failures)
	_check(int(modifiers.get("tutorial_pull_tab_xray_offset", -1)) == 2, "Tutorial X-ray pull-tab offset is not 2.", failures)
	_check(modifiers.get("tutorial_pull_tab_peek_results", []) == [true, false, true, false], "Tutorial Peek sequence must deterministically showcase two successes and two misses.", failures)

	var rourke_warning_levels: Array = []
	for event_value in library.events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		var speaker := _dict(event.get("speaker", {}))
		var trigger := _dict(event.get("trigger", {}))
		if str(speaker.get("character_id", "")) == "rourke_pit_boss" and str(trigger.get("type", "")) == "heat_threshold":
			rourke_warning_levels.append(int(trigger.get("level", -1)))
	_check(rourke_warning_levels == [85], "Rourke warning must be one heat-85 hook with no escalation ladder: %s" % JSON.stringify(rourke_warning_levels), failures)
	return {
		"ambient_tip_ids": ambient_ids,
		"authored_delivery_lessons": authored_delivery_count,
		"highlighted_lessons": highlighted_count,
		"pal": str(pal.get("display_name", "")),
		"host": str(host.get("display_name", "")),
		"rourke_warning_levels": rourke_warning_levels,
	}


func _tutorial_stuck_sweep(seed_count: int) -> Dictionary:
	var stuck: Array = []
	for seed_index in range(seed_count):
		var route_id := "path_a" if seed_index % 2 == 0 else "path_b_skip"
		var config: Dictionary = library.challenge_config_for("tutorial_first_card", "TUTORIAL-SWEEP-%03d" % seed_index)
		var run_state: RunState = RunStateScript.new()
		run_state.start_new(str(config.get("seed_text", "")), config)
		run_state.begin_act(1)
		var generator := RunGeneratorScript.new(library)
		generator.next_environment(run_state)
		var ok := str(run_state.current_environment.get("archetype_id", "")) == "apartment"
		ok = ok and _string_array(run_state.current_environment.get("next_archetypes", [])) == ["corner_store"]
		if ok:
			generator.next_environment(run_state, "corner_store", true)
			var tip := _resolve_event(run_state, "parking_lot_tip", "follow_tip")
			ok = bool(tip.get("ok", false))
		if ok and route_id == "path_a":
			generator.next_environment(run_state, "gas_station_casino", true)
			ok = str(run_state.current_environment.get("archetype_id", "")) == "gas_station_casino"
		if ok:
			generator.next_environment(run_state, "small_underground_casino", true)
			ok = str(run_state.current_environment.get("archetype_id", "")) == "small_underground_casino"
		if ok:
			var invite := _resolve_event(run_state, "tutorial_grand_casino_invitation", "accept_first_invitation")
			ok = bool(invite.get("ok", false)) and bool(run_state.narrative_flags.get("grand_casino_invite", false))
		if ok:
			generator.next_environment(run_state, "grand_casino", true)
			ok = str(run_state.current_environment.get("archetype_id", "")) == RunState.GRAND_CASINO_ARCHETYPE_ID
		if not ok:
			stuck.append({"index": seed_index, "route": route_id, "environment": str(run_state.current_environment.get("archetype_id", ""))})
	_check(stuck.is_empty(), "Tutorial route stuck-state sweep failed: %s" % JSON.stringify(stuck), failures)
	return {"iterations": seed_count, "path_a": int(ceil(float(seed_count) / 2.0)), "path_b_skip": int(floor(float(seed_count) / 2.0)), "stuck": stuck.size(), "fixed_seed": "FIRST-NIGHT-ACE-17"}


func _tutorial_lesson_boundary_save_load() -> Dictionary:
	var boundary_failures: Array = []
	var config: Dictionary = library.challenge_config_for("tutorial_first_card", "IGNORED-BY-FIXED-SEED")
	var current: RunState = RunStateScript.new()
	current.start_new(str(config.get("seed_text", "")), config)
	current.begin_act(1)
	RunGeneratorScript.new(library).next_environment(current)
	var completed: Dictionary = {}
	var checked_ids: Array = []
	for lesson_value in library.tutorial_lessons:
		if typeof(lesson_value) != TYPE_DICTIONARY:
			continue
		var lesson: Dictionary = lesson_value
		if str(lesson.get("scope", "")) != "tutorial_run":
			continue
		var lesson_id := str(lesson.get("id", "")).strip_edges()
		var dialogue_id := str(lesson.get("dialogue_id", "")).strip_edges()
		var dialogue_node := str(lesson.get("dialogue_node", "")).strip_edges()
		var event_id := "tutorial_guide:%s" % lesson_id
		current.narrative_flags["tutorial_lessons_completed"] = completed.duplicate(true)
		var queued := current.enqueue_dialogue(
			dialogue_id,
			event_id,
			{"name": "Pal"},
			dialogue_node,
			"dialogue",
			{"tutorial_lesson_id": lesson_id}
		)
		_check(queued, "Lesson-boundary save/load fixture could not queue %s." % lesson_id, boundary_failures)
		var restored: RunState = RunStateScript.new()
		restored.from_dict(current.to_dict())
		var restored_completed := _dict(restored.narrative_flags.get("tutorial_lessons_completed", {}))
		var restored_talk := restored.pending_talk_event(event_id)
		_check(
			JSON.stringify(restored_completed) == JSON.stringify(completed)
			and str(restored_talk.get("dialogue_id", "")) == dialogue_id
			and str(restored_talk.get("current_node", "")) == dialogue_node
			and str(_dict(restored_talk.get("context", {})).get("tutorial_lesson_id", "")) == lesson_id,
			"Tutorial lesson boundary changed across save/load at %s." % lesson_id,
			boundary_failures
		)
		restored.complete_talk_event_resolution(event_id)
		completed[lesson_id] = true
		restored.narrative_flags["tutorial_lessons_completed"] = completed.duplicate(true)
		current = RunStateScript.new()
		current.from_dict(restored.to_dict())
		checked_ids.append(lesson_id)
	for failure in boundary_failures:
		failures.append(failure)
	return {
		"boundaries_checked": checked_ids.size(),
		"lesson_ids": checked_ids,
		"failures": boundary_failures,
		"passed": boundary_failures.is_empty() and checked_ids.size() == library.tutorial_lessons.size(),
	}


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
	var first_destinations := _string_array(run_state.current_environment.get("next_archetypes", []))
	_check(first_destinations == ["corner_store"], "%s apartment map did not offer only the corner store: %s" % [route_id, JSON.stringify(first_destinations)], route_failures)
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
	var opened_routes := _string_array(run_state.current_environment.get("next_archetypes", []))
	_check(opened_routes.has("gas_station_casino") and opened_routes.has("small_underground_casino"), "%s parking tip did not leave both Path A and Path B open: %s" % [route_id, JSON.stringify(opened_routes)], route_failures)

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
	var gift_shop_state := _dict(run_state.current_environment.get("cage_gift_shop_state", {}))
	var gift_shop_stock := _dict_array(gift_shop_state.get("stock", []))
	_check(gift_shop_stock.size() >= 3, "%s Linda's Cage did not expose the real chips-only gift shop stock." % route_id, route_failures)
	var chip_purchase := run_state.buy_grand_casino_chips(10)
	_check(bool(chip_purchase.get("ok", false)) and run_state.grand_casino_chips >= 10, "%s could not buy chips from Linda." % route_id, route_failures)
	var linda_nodes: Dictionary = _dict(library.dialogue("linda_cage_services").get("nodes", {}))
	_check(str(_dict(linda_nodes.get("main", {})).get("tutorial_text", "")).contains("Cash buys chips") and str(_dict(linda_nodes.get("chips", {})).get("tutorial_text", "")).contains("pays debt first"), "%s Linda conversation did not expose the extended tutorial chip/debt explanation." % route_id, route_failures)
	var main_entered: bool = generator.enter_grand_casino_room(run_state, RunState.GRAND_CASINO_ARCHETYPE_ID)
	_check(main_entered, "%s could not return to the Main Floor." % route_id, route_failures)
	var grand_hand := _settle_grand_blackjack_hands(run_state, route_failures)
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
		"apartment": {"archetype": "apartment", "xray_picked_up": run_state.inventory.has("xray_glasses"), "first_destinations": first_destinations},
		"corner_store": {"offers": store_offer_ids, "family_debt_count": run_state.debt.size(), "tip_followed": bool(run_state.narrative_flags.get("underground_tip", false)), "opened_routes": opened_routes},
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
	var heat_before_peeks := run_state.suspicion_level()
	var peek_results: Array = []
	var peek_successes: Array = []
	var peek_base_heats: Array = []
	for peek_index in range(4):
		var peek_result := game.resolve_with_context("tab_detector_scan", 0, run_state, run_state.current_environment, run_state.create_rng("tutorial_pull_peek_%d" % peek_index), {})
		peek_successes.append(bool(peek_result.get("pull_tab_peek_succeeded", false)))
		peek_base_heats.append(int(peek_result.get("pull_tab_base_heat", 0)))
		peek_results.append({
			"succeeded": bool(peek_result.get("pull_tab_peek_succeeded", false)),
			"base_heat": int(peek_result.get("pull_tab_base_heat", 0)),
			"heat": int(peek_result.get("suspicion_delta", 0)),
		})
	_check(peek_successes == [true, false, true, false], "Path A Peek attempts did not showcase an exact two-success/two-miss split.", route_failures)
	_check(peek_base_heats == [8, 9, 10, 11], "Path A Peek Heat did not escalate 8, 9, 10, 11.", route_failures)
	var after_peeks := game.coach_state(run_state, run_state.current_environment, {})
	_check(int(after_peeks.get("peek_count", 0)) == 4 and int(after_peeks.get("peek_success_count", 0)) == 2, "Path A coach state did not record all four Peek attempts and both outcomes.", route_failures)
	_check(run_state.suspicion_level() > heat_before_peeks, "Path A Peek lesson did not raise the real Heat meter.", route_failures)
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
	var after_file := game.coach_state(run_state, run_state.current_environment, ui_state)
	_check(bool(after_file.get("scripted_target_filed", false)), "Path A did not peel and file the scripted X-ray winner itself.", route_failures)
	var before_redeem := run_state.bankroll
	var redeem_command := game.environment_action_command("ticket_redeemer", "redeem_pull_tab_winners", run_state, run_state.current_environment, run_state.create_rng("tutorial_pull_redeem"))
	var redeem_result: Dictionary = redeem_command.get("result", {}) if typeof(redeem_command.get("result", {})) == TYPE_DICTIONARY else {}
	if bool(redeem_result.get("ok", false)):
		GameModuleScript.apply_result(run_state, redeem_result, run_state.create_rng("tutorial_pull_redeem_apply"))
	_check(int(redeem_result.get("pull_tab_redeemed_payout", 0)) > 0 and run_state.bankroll > before_redeem, "Path A winner did not pay at the real clerk.", route_failures)
	return {"skipped": false, "peek_results": peek_results, "xray_target": target, "tickets_bought": bought_results, "redeemed_payout": int(redeem_result.get("pull_tab_redeemed_payout", 0))}


func _play_tutorial_blackjack(run_state: RunState, route_failures: Array) -> Dictionary:
	var game: GameModule = BlackjackScript.new()
	game.setup(library.game("blackjack"), library)
	game.enter(run_state, run_state.current_environment)
	var clean := _deal_and_stand(game, run_state, 2, "tutorial_clean")
	_check(bool(clean.get("settled", false)), "Tutorial blackjack normal hand did not settle.", route_failures)
	var deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 4}, run_state, run_state.current_environment)
	var deal_result := BlackjackAuthorityTestDriverScript.resolve(game, str(deal.get("action_id", "blackjack_place_bet")), 4, run_state, run_state.current_environment, run_state.create_rng("tutorial_raised_deal"), deal.get("ui_state", {}))
	var hand_state: Dictionary = deal.get("ui_state", {})
	var distraction := BlackjackAuthorityTestDriverScript.surface_intent(game, "blackjack_distraction", 4, run_state, run_state.current_environment)
	var distracted_state: Dictionary = distraction.get("ui_state", {})
	var peek := BlackjackAuthorityTestDriverScript.surface_intent(game, "blackjack_peek", 4, run_state, run_state.current_environment, 0, true)
	var peek_state: Dictionary = peek.get("ui_state", {})
	var peek_result := BlackjackAuthorityTestDriverScript.resolve_surface_command(game, peek, 0, run_state, run_state.current_environment)
	_check(bool(peek_state.get("peek_had_window", false)) and bool(peek_state.get("dealer_hole_visible", false)) and bool(peek_result.get("ok", false)), "Tutorial peek did not use the real distraction lookaway window.", route_failures)
	var preserved_peek_state: Dictionary = peek_result.get("blackjack_surface_ui_state", peek_state) if typeof(peek_result.get("blackjack_surface_ui_state", peek_state)) == TYPE_DICTIONARY else peek_state
	BlackjackAuthorityTestDriverScript.pin_protected_peek_settlement_rng(run_state)
	var peek_finish := BlackjackAuthorityTestDriverScript.surface_intent(game, "blackjack_stand", 4, run_state, run_state.current_environment)
	var peek_finish_result: Dictionary = {}
	if bool(peek_finish.get("resolve", false)):
		peek_finish_result = BlackjackAuthorityTestDriverScript.resolve_surface_command(game, peek_finish, 4, run_state, run_state.current_environment)
	var peek_finish_table: Dictionary = run_state.current_environment.get("game_states", {}).get("blackjack", {})
	_check(not bool(peek_finish_result.get("dealer_caught_cheat", false)) and not bool(peek_finish_table.get("barred", false)), "The fixed tutorial Peek settlement was caught or barred: %s" % JSON.stringify(peek_finish_result), route_failures)
	var peek_cleanup := BlackjackAuthorityTestDriverScript.advance_terminal_presentation(game, 4, run_state, run_state.current_environment)
	var after_peek_hand := game.coach_state(run_state, run_state.current_environment, {})
	_check(bool(peek_finish_result.get("ok", false)) and bool(peek_cleanup.get("ok", false)) and int(after_peek_hand.get("hands_played", 0)) == 2 and bool(after_peek_hand.get("between_hands", false)), "Tutorial Peek hand did not settle and clear presentation before the separate counting hand: %s" % JSON.stringify(peek_cleanup), route_failures)
	var count_toggle := BlackjackAuthorityTestDriverScript.surface_intent(game, "blackjack_count", 4, run_state, run_state.current_environment)
	var count_deal := BlackjackAuthorityTestDriverScript.surface_intent(game, "blackjack_deal", 4, run_state, run_state.current_environment)
	var count_deal_result := BlackjackAuthorityTestDriverScript.resolve_surface_command(game, count_deal, 4, run_state, run_state.current_environment)
	var count_state: Dictionary = count_deal_result.get("ui_state", count_deal.get("ui_state", {})) if typeof(count_deal_result.get("ui_state", count_deal.get("ui_state", {}))) == TYPE_DICTIONARY else count_deal.get("ui_state", {})
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
	var miss_run: RunState = RunStateScript.new()
	miss_run.from_dict(run_state.to_dict())
	var miss_game: GameModule = BlackjackScript.new()
	miss_game.setup(library.game("blackjack"), library)
	var miss_state := count_state.duplicate(true)
	var miss_challenge := _dict(miss_state.get("count_challenge", {}))
	var miss_icons := _dict_array(miss_challenge.get("icons", []))
	for icon_index in range(miss_icons.size()):
		var miss_icon: Dictionary = miss_icons[icon_index]
		miss_icon["spawn_msec"] = now - 10000
		miss_icon["duration_msec"] = 1
		miss_icons[icon_index] = miss_icon
	miss_challenge["icons"] = miss_icons
	miss_state["count_challenge"] = miss_challenge
	var miss_result := BlackjackAuthorityTestDriverScript.resolve(miss_game, "count_cards", 0, miss_run, miss_run.current_environment, miss_run.create_rng("tutorial_count_miss"), miss_state)
	var miss_final_state := _dict(miss_result.get("blackjack_surface_ui_state", miss_state))
	var miss_final_challenge := _dict(miss_final_state.get("count_challenge", {}))
	var miss_perfect := bool(miss_result.get("blackjack_count_perfect", miss_final_challenge.get("perfect", true)))
	_check(not miss_perfect and int(miss_result.get("suspicion_delta", 0)) > 0, "Missing real count pulses did not add heat: %s" % JSON.stringify(miss_result), route_failures)
	for icon_index in range(icons.size()):
		var live_icon: Dictionary = icons[icon_index]
		var icon_action_msec := int(live_icon.get("spawn_msec", now)) + 10
		count_state = BlackjackAuthorityTestDriverScript.surface_intent(game, "blackjack_count_icon", 4, run_state, run_state.current_environment, icon_index, false, icon_action_msec).get("ui_state", {})
	var coach_state := game.coach_state(run_state, run_state.current_environment, count_state)
	_check(not icons.is_empty() and bool(coach_state.get("count_all_selected", false)), "Tutorial count did not select every real count pulse.", route_failures)
	var count_result := BlackjackAuthorityTestDriverScript.resolve(game, "count_cards", 0, run_state, run_state.current_environment, run_state.create_rng("tutorial_count"), count_state)
	var final_count_state: Dictionary = count_result.get("blackjack_surface_ui_state", count_state) if typeof(count_result.get("blackjack_surface_ui_state", count_state)) == TYPE_DICTIONARY else count_state
	_check(bool(count_result.get("blackjack_count_answered", false)), "Tutorial count did not finalize through the real count action.", route_failures)
	var stand := BlackjackAuthorityTestDriverScript.surface_intent(game, "blackjack_stand", 4, run_state, run_state.current_environment)
	if bool(stand.get("resolve", false)):
		BlackjackAuthorityTestDriverScript.resolve_surface_command(game, stand, 4, run_state, run_state.current_environment)
	return {"normal_hand_settled": bool(clean.get("settled", false)), "peek_hand_settled": bool(peek_finish_result.get("ok", false)), "raised_bet": 4, "lookaway_id": str(distracted_state.get("dealer_lookaway_id", "")), "peek_had_window": bool(peek_state.get("peek_had_window", false)), "count_icon_count": icons.size(), "count_all_selected": bool(coach_state.get("count_all_selected", false)), "count_miss_heat_delta": int(miss_result.get("suspicion_delta", 0)), "raised_deal_ok": bool(deal_result.get("ok", false)), "count_deal_ok": bool(count_deal_result.get("ok", false))}


func _deal_and_stand(game: GameModule, run_state: RunState, stake: int, rng_label: String) -> Dictionary:
	var deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": stake}, run_state, run_state.current_environment)
	var deal_result := BlackjackAuthorityTestDriverScript.resolve(game, str(deal.get("action_id", "blackjack_place_bet")), stake, run_state, run_state.current_environment, run_state.create_rng("%s_deal" % rng_label), deal.get("ui_state", {}))
	var stand := BlackjackAuthorityTestDriverScript.surface_intent(game, "blackjack_stand", stake, run_state, run_state.current_environment)
	var stand_result := {}
	if bool(stand.get("resolve", false)):
		stand_result = BlackjackAuthorityTestDriverScript.resolve_surface_command(game, stand, stake, run_state, run_state.current_environment)
	var cleanup := BlackjackAuthorityTestDriverScript.advance_terminal_presentation(game, stake, run_state, run_state.current_environment)
	return {"deal_ok": bool(deal_result.get("ok", false)), "settled": bool(stand_result.get("ok", false)) and bool(cleanup.get("ok", false)), "result": stand_result, "cleanup": cleanup}


func _settle_grand_blackjack_hands(run_state: RunState, route_failures: Array) -> Dictionary:
	var game: GameModule = BlackjackScript.new()
	game.setup(library.game("blackjack"), library)
	game.enter(run_state, run_state.current_environment)
	var hands: Array = []
	for hand_index in range(2):
		var hand := _deal_and_stand(game, run_state, 1, "tutorial_grand_%d" % hand_index)
		hands.append(hand)
		_check(bool(hand.get("settled", false)), "Grand Casino tutorial table hand %d did not settle through Blackjack." % (hand_index + 1), route_failures)
	return {"settled": hands.all(func(hand): return bool((hand as Dictionary).get("settled", false))), "hands": hands}


func _normal_run_isolation() -> Dictionary:
	var config: Dictionary = library.challenge_config_for("standard", "NORMAL-ISOLATION")
	var modifiers: Dictionary = config.get("modifiers", {}) if typeof(config.get("modifiers", {})) == TYPE_DICTIONARY else {}
	var tutorial_modifier_keys := ["tutorial_run", "home_archetype_id", "tutorial_environment_overrides", "tutorial_forced_event_choices", "tutorial_event_chain_chances", "tutorial_pull_tab_xray_offset", "tutorial_pull_tab_peek_results", "tutorial_initial_map_targets", "tutorial_main_floor_only"]
	var leaked_modifier_keys: Array = []
	for key in tutorial_modifier_keys:
		if modifiers.has(key):
			leaked_modifier_keys.append(key)
	var normal_a: RunState = RunStateScript.new()
	normal_a.start_new("NORMAL-ISOLATION", config)
	normal_a.begin_act(1)
	var normal_generator_a := RunGeneratorScript.new(library)
	normal_generator_a.next_environment(normal_a)
	var normal_b: RunState = RunStateScript.new()
	normal_b.start_new("NORMAL-ISOLATION", config)
	normal_b.begin_act(1)
	var normal_generator_b := RunGeneratorScript.new(library)
	normal_generator_b.next_environment(normal_b)
	var normal_start_json := JSON.stringify(normal_a.current_environment)
	_check(normal_start_json == JSON.stringify(normal_b.current_environment), "Normal home/item generation is not byte-identical for the same seed.", failures)
	_check(leaked_modifier_keys.is_empty(), "Tutorial forcing leaked into normal config: %s" % JSON.stringify(leaked_modifier_keys), failures)
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
	var normal_control_run: RunState = RunStateScript.new()
	normal_control_run.start_new("NORMAL-PULL-TAB-ISOLATION", config)
	var normal_control_machine := pull_tabs.generate_environment_state(normal_control_run, normal_environment, normal_control_run.create_rng("normal_stock"))
	var scripted := false
	for deal in _dict_array(normal_machine.get("deals", [])):
		if bool(deal.get("tutorial_xray_scripted", false)):
			scripted = true
	var guarded_config := RunStateScript.custom_challenge("normal_guard_probe", "NORMAL-GUARD", {"tutorial_pull_tab_xray_offset": 2})
	var guarded_run: RunState = RunStateScript.new()
	guarded_run.start_new("NORMAL-GUARD", guarded_config)
	var guarded_machine := pull_tabs.generate_environment_state(guarded_run, normal_environment, guarded_run.create_rng("normal_guard_stock"))
	var guard_scripted := false
	for deal in _dict_array(guarded_machine.get("deals", [])):
		if bool(deal.get("tutorial_xray_scripted", false)):
			guard_scripted = true
	_check(JSON.stringify(normal_machine) == JSON.stringify(normal_control_machine), "Normal pull-tab stock changed for an identical seed.", failures)
	_check(not guard_scripted, "Pull-tab tutorial stock scripting ignored the tutorial-run guard.", failures)
	_check(normal_chain_chance == 0.75, "Normal family phone chance changed from 0.75.", failures)
	_check(not scripted, "Tutorial X-ray stock scripting leaked into a normal pull-tab machine.", failures)
	_check(int(objective.get("high_roller_net_winnings", -1)) == 30 and int(objective.get("high_roller_min_grand_casino_games", -1)) == 5 and int(objective.get("high_roller_max_heat", -1)) == 30, "Normal Grand Casino thresholds changed.", failures)
	_check(int(objective.get("players_card_bronze_min_games", -1)) == 1 and int(objective.get("players_card_bronze_net_winnings", -1)) == 5 and int(objective.get("players_card_bronze_max_heat", -1)) == 30, "Normal Bronze thresholds changed.", failures)
	_check(int(objective.get("players_card_silver_min_games", -1)) == 3 and int(objective.get("players_card_silver_net_winnings", -1)) == 15 and int(objective.get("players_card_silver_max_heat", -1)) == 30, "Normal Silver thresholds changed.", failures)
	_check(int(objective.get("players_card_gold_min_games", -1)) == 5 and int(objective.get("players_card_gold_net_winnings", -1)) == 30 and int(objective.get("players_card_gold_max_heat", -1)) == 30, "Normal Gold thresholds changed.", failures)
	var host_dialogue: Dictionary = library.dialogue("normal_grand_host_greeting")
	_check(str(_dict(host_dialogue.get("speaker", {})).get("character_id", "")) == "vivienne_grand_host", "Normal-run Host greeting is missing Vivienne.", failures)
	return {"tutorial_modifier_keys_absent": leaked_modifier_keys.is_empty(), "normal_start_hash": hash(normal_start_json), "normal_start_archetype": str(normal_a.current_environment.get("archetype_id", "")), "family_phone_chain_chance": normal_chain_chance, "pull_tab_stock_scripted": scripted, "pull_tab_guard_scripted": guard_scripted, "normal_stock_hash": hash(JSON.stringify(normal_machine)), "grand_thresholds": {"net": objective.get("high_roller_net_winnings", -1), "games": objective.get("high_roller_min_grand_casino_games", -1), "heat": objective.get("high_roller_max_heat", -1)}, "card_thresholds": {"bronze": [objective.get("players_card_bronze_min_games", -1), objective.get("players_card_bronze_net_winnings", -1), objective.get("players_card_bronze_max_heat", -1)], "silver": [objective.get("players_card_silver_min_games", -1), objective.get("players_card_silver_net_winnings", -1), objective.get("players_card_silver_max_heat", -1)], "gold": [objective.get("players_card_gold_min_games", -1), objective.get("players_card_gold_net_winnings", -1), objective.get("players_card_gold_max_heat", -1)]}, "host_greeting_dialogue": str(host_dialogue.get("id", ""))}


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
	var output_json := "%s/tutorial_guided_run_audit.json" % output_dir
	var output_markdown := "%s/tutorial_guided_run_audit.md" % output_dir
	var absolute_json := ProjectSettings.globalize_path(output_json)
	DirAccess.make_dir_recursive_absolute(absolute_json.get_base_dir())
	var json_file := FileAccess.open(output_json, FileAccess.WRITE)
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
	lines.append("- Authored delivery: `%s`" % JSON.stringify(report.get("authored_contract", {})))
	lines.append("- Normal isolation: `%s`" % JSON.stringify(report.get("normal_run_isolation", {})))
	lines.append("- Tutorial stuck sweep: `%s`" % JSON.stringify(report.get("tutorial_stuck_sweep", {})))
	if not report.get("failures", []).is_empty():
		lines.append("")
		lines.append("## Failures")
		for failure in report.get("failures", []):
			lines.append("- %s" % str(failure))
	var markdown_file := FileAccess.open(output_markdown, FileAccess.WRITE)
	markdown_file.store_string("\n".join(lines) + "\n")
	markdown_file.close()
