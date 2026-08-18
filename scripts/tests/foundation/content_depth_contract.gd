class_name ContentDepthContract
extends RefCounted

const EventModuleScript := preload("res://scripts/core/event_module.gd")
const GameModuleScript := preload("res://scripts/core/game_module.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")
const BarDiceScript := preload("res://scripts/games/bar_dice.gd")
const BaccaratScript := preload("res://scripts/games/baccarat.gd")
const RouletteScript := preload("res://scripts/games/roulette.gd")
const CoinPusherScript := preload("res://scripts/games/coin_pusher.gd")
const JackpotRidgeScript := preload("res://scripts/games/coin_pusher/jackpot_ridge.gd")

const SOUVENIR_EVENTS := {
	"scenario_delivery_day_stock": "delivery_twine",
	"scenario_lotto_fever_jackpot": "lotto_queue_number",
	"scenario_aftermath_fence_offer": "boarded_window_nail",
	"scenario_wake_route_story": "wake_matchbook",
	"scenario_fight_night_swing_bet": "fight_night_betting_slip",
	"scenario_lock_in_private_game": "lock_in_door_chit",
	"scenario_trucker_convoy_route": "convoy_cb_tag",
	"scenario_tour_bus_ticket_rush": "tour_bus_luggage_tag",
	"scenario_rent_party_hat": "rent_party_hat_pin",
	"scenario_recording_night_tape": "recording_room_tape",
	"scenario_wedding_best_man": "wedding_ribbon_favor",
	"scenario_festival_lucky_pitch": "festival_brass_token",
	"scenario_estate_lot_provenance": "estate_map_clasp",
}
const BENCH_OUTPUTS := ["mags_loaded_dice", "mags_tuned_loupe", "mags_lined_sleeve", "mags_nudge_dampener", "mags_shim_kit"]


static func check(library: ContentLibrary, failures: Array) -> void:
	_check_souvenirs(library, failures)
	_check_scenario_budgets(library, failures)
	_check_services(library, failures)
	_check_bench(library, failures)


static func _check_souvenirs(library: ContentLibrary, failures: Array) -> void:
	for event_id_value in SOUVENIR_EVENTS.keys():
		var event_id := str(event_id_value)
		var item_id := str(SOUVENIR_EVENTS[event_id_value])
		var item := library.item(item_id)
		var event := library.event(event_id)
		if item.is_empty() or str(item.get("class", "")) != "souvenir" or _dict(item.get("effect", {})).is_empty():
			failures.append("Content souvenir %s is missing or has no existing-system effect." % item_id)
			continue
		if event.is_empty():
			failures.append("Content souvenir %s has no scenario acquisition event." % item_id)
			continue
		var run := RunStateScript.new()
		run.start_new("CONTENT-SOUVENIR-%s" % event_id)
		var scope := str(_array(event.get("scopes", ["any"]))[0])
		run.current_environment = {"id": event_id, "archetype_id": "fixture", "kind": scope, "tier": 1, "event_ids": [event_id], "resolved_event_ids": []}
		var module := EventModuleScript.new()
		module.setup(event, library)
		var options := module.choices(run, run.current_environment)
		if options.is_empty():
			failures.append("Content souvenir %s acquisition has no choice." % item_id)
			continue
		var result := module.resolve(run, run.current_environment, str((options[0] as Dictionary).get("id", "")))
		if not _array(_dict(result.get("deltas", {})).get("inventory_add", [])).has(item_id):
			failures.append("Content souvenir %s does not enter inventory through its scenario path." % item_id)
	_check_seeded_scenario_souvenir_pipeline(library, failures)


static func _check_seeded_scenario_souvenir_pipeline(library: ContentLibrary, failures: Array) -> void:
	const TARGET_ARCHETYPE := "delta_queen"
	const TARGET_SCENARIO := "delta_queen_wedding_charter"
	const TARGET_EVENT := "scenario_wedding_best_man"
	const TARGET_ITEM := "wedding_ribbon_favor"
	var selected_run: RunState
	for seed_index in range(512):
		var candidate := RunStateScript.new()
		candidate.start_new("CONTENT-PRODUCTION-SCENARIO-%03d" % seed_index)
		var generator := RunGeneratorScript.new(library)
		generator.next_environment(candidate)
		generator.next_environment(candidate, TARGET_ARCHETYPE, true)
		if str(candidate.current_environment.get("scenario_id", "")) == TARGET_SCENARIO:
			selected_run = candidate
			break
	if selected_run == null:
		failures.append("Seeded production generation never selected %s in the deterministic probe window." % TARGET_SCENARIO)
		return
	if not _array(selected_run.current_environment.get("event_ids", [])).has(TARGET_EVENT):
		failures.append("Seeded production scenario %s did not inject authored event %s." % [TARGET_SCENARIO, TARGET_EVENT])
		return
	var module := EventModuleScript.new()
	module.setup(library.event(TARGET_EVENT), library)
	var choices := module.choices(selected_run, selected_run.current_environment)
	if choices.is_empty():
		failures.append("Seeded production scenario event %s exposed no acquisition choice." % TARGET_EVENT)
		return
	var result := module.resolve(selected_run, selected_run.current_environment, str((choices[0] as Dictionary).get("id", "")))
	if not bool(result.get("ok", false)):
		failures.append("Seeded production scenario event %s failed its standard EventModule application." % TARGET_EVENT)
	if not selected_run.inventory.has(TARGET_ITEM):
		failures.append("Seeded generation -> scenario -> event -> standard result did not acquire %s." % TARGET_ITEM)
		return
	var acquired_environment := selected_run.current_environment.duplicate(true)
	selected_run.set_environment({"id": "souvenir_travel_probe", "archetype_id": "roadside", "kind": "roadside", "tier": 1, "event_ids": [], "resolved_event_ids": []})
	if not selected_run.inventory.has(TARGET_ITEM):
		failures.append("Scenario souvenir did not survive within-run travel.")
	selected_run.set_environment(acquired_environment)
	var saved_run := selected_run.to_dict()
	var restored := RunStateScript.new()
	restored.from_dict(saved_run)
	if not restored.inventory.has(TARGET_ITEM) or not _array(restored.current_environment.get("resolved_event_ids", [])).has(TARGET_EVENT):
		failures.append("Scenario souvenir or its resolved acquisition did not survive save/load/revisit.")
		return
	# Model a legitimate within-run resale by removing the owned item. Reloading
	# or revisiting the source must not reopen the resolved event as an item farm.
	restored.inventory.erase(TARGET_ITEM)
	var repeat_trigger := module.can_trigger(restored, restored.current_environment)
	if repeat_trigger:
		module.resolve(restored, restored.current_environment, str((choices[0] as Dictionary).get("id", "")))
	if repeat_trigger or restored.inventory.has(TARGET_ITEM):
		failures.append("Scenario souvenir could be reacquired for repeat resale after reload/revisit.")
	var fresh_run := RunStateScript.new()
	fresh_run.start_new("CONTENT-SOUVENIR-FRESH-RUN")
	if fresh_run.inventory.has(TARGET_ITEM) or _array(fresh_run.to_dict().get("inventory", [])).has(TARGET_ITEM):
		failures.append("Within-run scenario souvenir leaked into fresh-run/meta state.")


static func _check_scenario_budgets(library: ContentLibrary, failures: Array) -> void:
	for archetype_value in library.environment_scenarios.keys():
		for scenario_value in _array(library.environment_scenarios.get(archetype_value, [])):
			var scenario: Dictionary = scenario_value
			var events := _array(_dict(scenario.get("mutations", {})).get("event_pool_add", []))
			if events.size() < 1 or events.size() > 3:
				failures.append("Scenario %s has %d exclusive events; launch budget is 1-3." % [str(scenario.get("id", "")), events.size()])
			for event_id_value in events:
				if library.event(str(event_id_value)).is_empty():
					failures.append("Scenario %s references missing event %s." % [str(scenario.get("id", "")), str(event_id_value)])


static func _check_services(library: ContentLibrary, failures: Array) -> void:
	for service_id in ["scenario_open_bar", "punchline_cover_charge", "punchline_private_table", "punchline_two_drink_minimum"]:
		var service := library.service(service_id)
		if service.is_empty() or _dict(service.get("effect", {})).is_empty():
			failures.append("Scenario service %s is missing a concrete effect." % service_id)


static func _check_bench(library: ContentLibrary, failures: Array) -> void:
	var definition := library.event("crew_mags_bench")
	var catalog := _array(_dict(definition.get("payload", {})).get("catalog", []))
	if catalog.size() < 4 or catalog.size() > 6:
		failures.append("Mags' bench must carry 4-6 upgrades; found %d." % catalog.size())
	var outputs := []
	for entry_value in catalog:
		var entry: Dictionary = entry_value
		var output := str(entry.get("output_item", ""))
		outputs.append(output)
		if library.item(output).is_empty() or int(entry.get("cash_cost", 0)) <= 0 or _array(entry.get("requires_items", [])).is_empty() or str(entry.get("risk_delta_note", "")).is_empty():
			failures.append("Bench entry %s lost item, cash, component, or risk documentation." % str(entry.get("id", "")))
	for output in BENCH_OUTPUTS:
		if not outputs.has(output):
			failures.append("Mags' bench is missing %s." % output)
	var run := RunStateScript.new()
	run.start_new("CONTENT-BENCH")
	run.bankroll = 500
	run.current_environment = {"id": "bench", "archetype_id": "small_underground_casino", "kind": "crew", "event_ids": ["crew_mags_bench"], "resolved_event_ids": []}
	var module := EventModuleScript.new()
	module.setup(definition, library)
	if module.choices(run, run.current_environment).size() != 1:
		failures.append("Mags' bench exposed gear before Mags' rank gate.")
	for entry_value in catalog:
		_check_bench_entry_matrix(module, entry_value as Dictionary, run.current_environment, failures)
	run.crew_add_trust("crew_mags", CrewStateModelScript.rank_threshold("inner_circle"), "content_fixture")
	for entry_value in catalog:
		for item_id_value in _array((entry_value as Dictionary).get("requires_items", [])):
			if not run.inventory.has(str(item_id_value)):
				run.inventory.append(str(item_id_value))
	var available := module.choices(run, run.current_environment)
	if available.size() != catalog.size() + 1:
		failures.append("Mags' full-rank/cash/component gate did not expose the complete catalog.")
	_check_bench_runtime_consumers(library, failures)
	run.bankroll = 0
	if module.choices(run, run.current_environment).size() != 1:
		failures.append("Mags' bench cash gate exposed an unaffordable upgrade.")


static func _check_bench_entry_matrix(module: EventModule, entry: Dictionary, environment: Dictionary, failures: Array) -> void:
	var choice_id := str(entry.get("id", ""))
	var output_id := str(entry.get("output_item", ""))
	var min_rank := str(entry.get("min_member_rank", ""))
	var cash_cost := int(entry.get("cash_cost", 0))
	var components := _array(entry.get("requires_items", []))
	var rank_index := CrewStateModelScript.RANK_IDS.find(min_rank)
	var run := RunStateScript.new()
	run.start_new("CONTENT-BENCH-MATRIX-%s" % output_id)
	run.current_environment = environment.duplicate(true)
	run.bankroll = cash_cost
	var lower_rank := str(CrewStateModelScript.RANK_IDS[maxi(0, rank_index - 1)])
	run.crew_add_trust("crew_mags", CrewStateModelScript.rank_threshold(lower_rank), "content_fixture")
	for component_value in components:
		run.add_item(str(component_value))
	if _has_choice(module.choices(run, run.current_environment), choice_id):
		failures.append("Bench %s bypassed its exact %s rank gate." % [output_id, min_rank])
	var trust_needed := CrewStateModelScript.rank_threshold(min_rank) - run.crew_trust("crew_mags")
	if trust_needed > 0:
		run.crew_add_trust("crew_mags", trust_needed, "content_fixture")
	var missing_component := str(components[0]) if not components.is_empty() else ""
	if not missing_component.is_empty():
		run.remove_item(missing_component)
	if _has_choice(module.choices(run, run.current_environment), choice_id):
		failures.append("Bench %s bypassed its exact component gate." % output_id)
	if not missing_component.is_empty():
		run.add_item(missing_component)
	run.bankroll = cash_cost - 1
	if _has_choice(module.choices(run, run.current_environment), choice_id):
		failures.append("Bench %s bypassed its exact $%d cash gate." % [output_id, cash_cost])
	run.bankroll = cash_cost
	if not _has_choice(module.choices(run, run.current_environment), choice_id):
		failures.append("Bench %s did not open at its authored rank/cash/component boundary." % output_id)
		return
	var result := module.resolve(run, run.current_environment, choice_id)
	var deltas := _dict(result.get("deltas", {}))
	if not bool(result.get("ok", false)) \
		or int(deltas.get("bankroll_delta", 0)) != -cash_cost \
		or _array(deltas.get("inventory_remove", [])) != components \
		or _array(deltas.get("inventory_add", [])) != [output_id]:
		failures.append("Bench %s did not emit its exact cash/component/output matrix." % output_id)


static func _check_bench_runtime_consumers(library: ContentLibrary, failures: Array) -> void:
	var loaded := RunStateScript.new()
	loaded.start_new("CONTENT-LOADED-DICE-CONSUMER")
	loaded.add_item("mags_loaded_dice")
	var dice := BarDiceScript.new()
	dice.setup(library.game("bar_dice"), library)
	var dice_windows := dice._controlled_roll_windows(loaded)
	if int(dice_windows.get("perfect", 0)) != dice.CONTROLLED_ROLL_PERFECT_WINDOW_MSEC + 45 \
		or int(dice_windows.get("good", 0)) != dice.CONTROLLED_ROLL_GOOD_WINDOW_MSEC + 80 \
		or dice._controlled_roll_base_heat(loaded) != maxi(1, dice.CONTROLLED_ROLL_BASE_HEAT - 3):
		failures.append("Mags' loaded dice did not arrive at Bar Dice's existing timing/heat consumers.")

	var loupe := RunStateScript.new()
	loupe.start_new("CONTENT-TUNED-LOUPE-CONSUMER")
	loupe.add_item("mags_tuned_loupe")
	var baccarat := BaccaratScript.new()
	baccarat.setup(library.game("baccarat"), library)
	if baccarat._edge_sort_required_cue_count(loupe) != maxi(3, baccarat.EDGE_SORT_CUE_COUNT - 2) \
		or baccarat._edge_sort_memory_tolerance(loupe) != 2 \
		or baccarat._edge_sort_base_heat(loupe) != maxi(1, baccarat.EDGE_SORT_BASE_HEAT - 3):
		failures.append("Mags' tuned loupe did not arrive at Baccarat's existing edge-sort consumers.")

	var sleeve := RunStateScript.new()
	sleeve.start_new("CONTENT-LINED-SLEEVE-CONSUMER")
	sleeve.add_item("mags_lined_sleeve")
	var generic_slots := GameModuleScript.new()
	generic_slots.setup(library.game("slot"), library)
	var roulette := RouletteScript.new()
	roulette.setup(library.game("roulette"), library)
	var roulette_windows := roulette._past_post_windows(sleeve)
	if generic_slots._item_bonus("win_chance", sleeve, false) != 7 \
		or int(roulette_windows.get("perfect", 0)) != roulette.PAST_POST_PERFECT_MSEC + 30 \
		or roulette._past_post_base_heat(sleeve) != maxi(1, roulette.PAST_POST_BASE_HEAT - 4):
		failures.append("Mags' lined sleeve did not arrive at Slots/Roulette's existing generic consumers.")

	var dampener := RunStateScript.new()
	dampener.start_new("CONTENT-NUDGE-DAMPENER-CONSUMER")
	dampener.add_item("mags_nudge_dampener")
	if dampener.item_effect_total("coin_pusher_nudge_tolerance_band_delta", "coin_pusher") != 1 \
		or JackpotRidgeScript.tolerance_band_bonus(dampener, {"tolerance_band_size": 2}) != 2:
		failures.append("Mags' nudge dampener did not arrive at Jackpot Ridge's existing tolerance-band consumer.")

	var shim := RunStateScript.new()
	shim.start_new("CONTENT-GUTTER-KIT-CONSUMER")
	shim.add_item("mags_shim_kit")
	var pusher := CoinPusherScript.new()
	pusher.setup(library.game("coin_pusher"), library)
	if pusher._shim_uses(shim) != 4:
		failures.append("Mags' gutter kit did not arrive at the coin pusher's existing recovery-use consumer.")


static func _array(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []


static func _has_choice(choices: Array, choice_id: String) -> bool:
	for choice_value in choices:
		if typeof(choice_value) == TYPE_DICTIONARY and str((choice_value as Dictionary).get("id", "")) == choice_id:
			return true
	return false


static func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}
