class_name ContentDepthContract
extends RefCounted

const EventModuleScript := preload("res://scripts/core/event_module.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")

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
const BENCH_OUTPUTS := ["mags_loaded_dice", "mags_tuned_loupe", "mags_lined_sleeve", "mags_shim_kit"]


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
	run.crew_add_trust("crew_mags", CrewStateModelScript.rank_threshold("inner_circle"), "content_fixture")
	for entry_value in catalog:
		for item_id_value in _array((entry_value as Dictionary).get("requires_items", [])):
			if not run.inventory.has(str(item_id_value)):
				run.inventory.append(str(item_id_value))
	var available := module.choices(run, run.current_environment)
	if available.size() != catalog.size() + 1:
		failures.append("Mags' full-rank/cash/component gate did not expose the complete catalog.")
	if not catalog.is_empty():
		var first_entry: Dictionary = catalog[0]
		var resolved := module.resolve(run, run.current_environment, str(first_entry.get("id", "")))
		var deltas := _dict(resolved.get("deltas", {}))
		if not bool(resolved.get("ok", false)):
			failures.append("Mags' bench could not resolve an available catalog choice.")
		if int(deltas.get("bankroll_delta", 0)) != -int(first_entry.get("cash_cost", 0)):
			failures.append("Mags' bench did not emit the catalog cash delta through the standard action result.")
		if _array(deltas.get("inventory_remove", [])) != _array(first_entry.get("requires_items", [])):
			failures.append("Mags' bench did not consume the authored component list through the standard action result.")
		if _array(deltas.get("inventory_add", [])) != [str(first_entry.get("output_item", ""))]:
			failures.append("Mags' bench did not emit its authored upgrade through the standard action result.")
	run.bankroll = 0
	if module.choices(run, run.current_environment).size() != 1:
		failures.append("Mags' bench cash gate exposed an unaffordable upgrade.")


static func _array(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []


static func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}
