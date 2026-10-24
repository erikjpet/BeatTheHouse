extends SceneTree

const Run := preload("res://scripts/core/run_state.gd")
const Town := preload("res://scripts/core/town_state.gd")

class PricingTown extends Town:
	var multiplier := 1.2
	func travel_modifier_profile() -> Dictionary:
		return {"cost_multiplier": multiplier}

var failures: Array[String] = []
var checks := 0

func _init() -> void:
	var run := Run.new()
	run.start_new("CASINO-ROOM-BUY-IN-PRICE")
	run.current_environment = {"id": Run.GRAND_CASINO_ARCHETYPE_ID, "archetype_id": Run.GRAND_CASINO_ARCHETYPE_ID}
	var town := PricingTown.new()
	run.town_state = town
	var room := {"id": Run.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID, "cost": 60, "distance": "near", "travel_method": "Inside", "local_casino_room": true}
	for multiplier in [1.08, 1.5, 0.5]:
		town.multiplier = multiplier
		_check(run._travel_route_cost(room) == 60, "A casino room buy-in must retain its quoted price under town multiplier %s." % multiplier)
	town.multiplier = 1.5
	var free_room := room.duplicate(true)
	free_room["cost"] = 0
	_check(run._travel_route_cost(free_room) == 0, "Free casino doors and card access must remain free.")
	var bus := {"id": "paid_bus", "cost": 10, "distance": "far", "travel_method": "Bus"}
	_check(run._travel_route_cost(bus) == 15, "Outdoor bus fares must still use town pricing.")
	run.narrative_flags["crew_rook_ride_active"] = true
	run.narrative_flags["crew_rook_ride_discount_percent"] = 25
	_check(run._travel_route_cost(bus) == 12, "The existing ride discount must still apply to outdoor transport.")
	_check(run._travel_route_cost(room) == 60, "A ride discount must not discount a casino access buy-in.")
	var walk := bus.duplicate(true)
	walk["travel_method"] = "Walk"
	_check(run._travel_route_cost(walk) == 0, "Ordinary walking must remain free.")
	var normalized_room := room.duplicate(true)
	normalized_room["travel_method_kind"] = "walk"
	_check(run._travel_route_cost(normalized_room) == 60, "Transport-method normalization must not erase the room buy-in.")
	run.narrative_flags.erase("crew_rook_ride_active")
	run.bankroll = 59
	_check(not bool(run.grand_casino_room_access_status(Run.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID, 60).get("available", true)), "Room access must still reject less than the required cash buy-in.")
	run.bankroll = 60
	_check(bool(run.grand_casino_room_access_status(Run.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID, 60).get("available", false)), "The exact quoted cash buy-in must satisfy room access.")
	var rng := run.rng_state
	var status := run.travel_route_status(room)
	_check(bool(status.get("available", false)) and int(status.get("cost", -1)) == 60, "Transport affordability must agree with the exact room buy-in.")
	_check(run.bankroll == 60 and run.rng_state == rng, "Price and availability queries must not spend funds or consume RNG.")
	run.narrative_flags["grand_casino_high_limit_access"] = true
	_check(int(run.grand_casino_room_access_status(Run.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID, 60).get("cost", -1)) == 0, "Existing high-limit access must not request a second buy-in.")
	print("CASINO_ROOM_BUY_IN_PRICE_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
