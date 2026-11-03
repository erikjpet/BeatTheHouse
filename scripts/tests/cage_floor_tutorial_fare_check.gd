extends SceneTree

# Genuine576 established the failure. These synthetic fixtures exercise the
# actual quote, departure price, travel-result builder and currency application.
# They do not replay the original trip or claim full room-install/Web coverage.
const State := preload("res://scripts/core/run_state.gd")
const Main := preload("res://scripts/ui/foundation_main.gd")
const Controller := preload("res://scripts/ui/environment_interaction_controller.gd")

class DoorHost extends RefCounted:
	const AttributeBadgesScript := preload("res://scripts/core/attribute_badges.gd")
	var run_state: RunState
	var archetypes: Dictionary = {}
	func _environment_archetype(id: String) -> Dictionary:
		return archetypes.get(id, {})
	func _travel_label_from_archetype(archetype: Dictionary, id: String) -> String:
		return str(archetype.get("display_name", id))

var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _state(seed: String, tutorial: bool = true) -> RunState:
	var state := State.new()
	state.start_new(seed, {"tutorial": tutorial, "modifiers": {"tutorial_travel_cost_overrides": {"grand_casino": 5}}})
	return state

func _room(definition: Dictionary) -> Dictionary:
	return {"id": str(definition.id), "archetype_id": str(definition.id), "display_name": str(definition.display_name), "world_node_id": "grand_casino", "local_narrative_flags": (definition.local_narrative_flags as Dictionary).duplicate(true)}

func _run() -> void:
	var private_root := OS.get_environment("BTH_CAGE_FARE_ROOT").replace("\\", "/")
	_check(not private_root.is_empty() and ProjectSettings.globalize_path("user://").replace("\\", "/").begins_with(private_root + "/"), "Use only the fresh synthetic storage root.")
	if not failures.is_empty():
		_finish()
		return
	var host := DoorHost.new()
	var definitions: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/environments/archetypes.json"))
	for value in definitions:
		host.archetypes[str(value.id)] = value
	var run := _state("CAGE-FLOOR-TUTORIAL-FARE")
	run.current_environment = _room(host.archetypes.grand_casino_cage)
	run.bankroll = 121
	var exchange: Dictionary = run.buy_grand_casino_chips(25)
	_check(bool(exchange.get("ok", false)) and run.bankroll == 96 and run.grand_casino_chips == 25, "The real chip exchange reproduces the observed121->96cash/25chips starting boundary.")
	host.run_state = run
	var before_query := var_to_bytes(run.to_dict())
	var choice := Controller.casino_room_door_travel_choice(host, "grand_casino")
	_check(not choice.is_empty() and bool(choice.get("enabled", false)), "The authored Cage return door remains available.")
	var route: Dictionary = choice.get("route", {})
	_check(bool(route.get("local_casino_room", false)) and int(route.get("cost", -1)) == 0 and int(choice.get("cost", -1)) == 0, "The real room card and authored internal route both quote0.")
	var departure := run.travel_route_status(route)
	_check(int(departure.get("cost", -1)) == int(choice.get("cost", -2)), "Effective departure price agrees with the displayed free room quote.")
	_check(var_to_bytes(run.to_dict()) == before_query, "Quote/availability reads do not mutate money, chips, RNG, clock or saved state.")
	var main := Main.new()
	main.run_state = run
	var destination := _room(host.archetypes.grand_casino)
	var result: Dictionary = main.call("_travel_result", "grand_casino", "Grand Casino Main Floor", route, run.current_environment, destination, {}, {}, departure)
	_check(int(result.get("route_cost", -1)) == 0 and int(result.get("bankroll_delta", -1)) == 0, "Actual travel-result construction publishes a zero debit.")
	var rng_before: int = run.rng_state
	var applied: Dictionary = GameModule.apply_result(run, result)
	_check(bool(applied.get("ok", false)) and run.bankroll == 96 and run.grand_casino_chips == 25, "Applying the real travel result preserves96cash/25chips; no phantom5charge.")
	_check(run.rng_state == rng_before, "No route RNG is consumed by this synthetic internal fare/application check.")
	var story: Dictionary = run.story_log[-1]
	_check(str(story.get("type", "")) == "travel" and int(story.get("route_cost", -1)) == 0 and int(story.get("bankroll_delta", -1)) == 0, "The travel journal records the same zero price and debit.")
	var count_after := run.story_log.size()
	for repeat in range(3):
		_check(int(run.travel_route_status(route).get("cost", -1)) == 0 and run.bankroll == 96 and run.story_log.size() == count_after, "Repeated quote%d does not charge or replay the completed result." % repeat)
	for source in ["grand_casino", "grand_casino_cage", "grand_casino_high_limit"]:
		run.current_environment = _room(host.archetypes[source])
		for target in run.current_environment.local_narrative_flags.get("casino_room_targets", []):
			var projected := Controller.casino_room_door_travel_choice(host, str(target))
			if projected.is_empty():
				continue
			var priced := run.travel_route_status(projected.route)
			_check(int(priced.cost) == int(projected.cost), "%s->%s preserves its exact authored interior price." % [source, target])
	run.current_environment = _room(host.archetypes.grand_casino_cage)
	run.bankroll = 0
	var free_at_zero := Controller.casino_room_door_travel_choice(host, "grand_casino")
	_check(bool(free_at_zero.get("enabled", false)) and int(run.travel_route_status(free_at_zero.route).cost) == 0, "A zero-cash player is not stranded behind the tutorial's outdoor fare.")
	var public_route := {"id": "grand_casino", "destination_archetype": "grand_casino", "target_node_id": "grand_casino", "cost": 17, "distance": "far", "travel_method": "Bus"}
	_check(run._travel_route_cost(public_route) == 5, "The intended public Grand tutorial fare stays5.")
	var buy_in := {"id": "grand_casino_high_limit", "destination_archetype": "grand_casino_high_limit", "target_node_id": "grand_casino", "cost": 60, "distance": "near", "travel_method_kind": "walk", "local_casino_room": true}
	_check(run._travel_route_cost(buy_in) == 60, "Authored paid High-Limit admission stays60, even after Inside normalizes to walk.")
	run.bankroll = 59
	_check(not bool(run.travel_route_status(buy_in).available), "An unaffordable real interior admission remains blocked.")
	run.bankroll = 60
	_check(bool(run.travel_route_status(buy_in).available), "Exactly60 still satisfies actual admission affordability.")
	var ordinary := _state("NON-TUTORIAL-INTERIOR", false)
	ordinary.current_environment = _room(host.archetypes.grand_casino_cage)
	_check(ordinary._travel_route_cost(route) == 0 and ordinary._travel_route_cost(buy_in) == 60, "Non-tutorial interior prices are unchanged.")
	# Preserve an already accepted historical5debit. Only future pricing changes.
	var legacy := _state("SYNTHETIC-OLD-ACCEPTED-FARE")
	legacy.current_environment = _room(host.archetypes.grand_casino_cage)
	legacy.bankroll = 96
	legacy.grand_casino_chips = 25
	main.run_state = legacy
	var old_result: Dictionary = main.call("_travel_result", "grand_casino", "Grand Casino Main Floor", route, legacy.current_environment, destination, {}, {}, {"cost": 5})
	GameModule.apply_result(legacy, old_result)
	var restored := State.new()
	restored.from_dict(legacy.to_dict())
	_check(restored.bankroll == 91 and restored.grand_casino_chips == 25, "Existing accepted wallet/chips load without an invented refund.")
	_check(int(restored.story_log[-1].get("route_cost", -1)) == 5 and int(restored.story_log[-1].get("bankroll_delta", 0)) == -5, "Historical paid travel receipt remains unchanged after restoration.")
	_check(restored._travel_route_cost(route) == 0 and restored._travel_route_cost(public_route) == 5, "Restored old tutorial modifiers price future interior/public routes correctly.")
	facts = {"quote": int(choice.cost), "departure_cost": int(departure.cost), "applied_cash": 96, "chips": 25, "public_tutorial_fare": 5, "paid_room_admission": 60, "historical_wallet_preserved": restored.bankroll}
	main.free()
	_finish()

func _finish() -> void:
	for failure in failures:
		push_error(failure)
	print("CAGE_FLOOR_TUTORIAL_FARE ", JSON.stringify({"checks": checks, "failures": failures, "facts": facts, "fidelity": "Synthetic authored door projection + real price/result/application and model restoration. Not original R02 replay, generator installation or disk Save/cold Web."}))
	quit(0 if failures.is_empty() else 1)
