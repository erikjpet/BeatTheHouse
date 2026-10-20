extends SceneTree

# Focused native contract; no rendered scene or game loop is started.
# godot --headless --path . --script res://scripts/tests/character_offers_roads_and_ride_check.gd

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const OfferModel := preload("res://scripts/core/character_offer_model.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunSaveCodecScript := preload("res://scripts/core/run_save_codec.gd")
const WorldMapScript := preload("res://scripts/core/world_map.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const OX_ID := "ox_knows_the_roads"
const RIDE_ID := "rafi_grand_casino_ride"
const COFFEE_ID := "rafi_last_coffee"
const STATE_KEY := "character_offer_cycles"


# Only presentation and disk writes are replaced. The successful ride uses the
# production claim, clock, fare, route, generator, travel and consequence code.
class RideHost extends "res://scripts/ui/foundation_main.gd":
	var saved_targets: Array = []

	func _refresh() -> void:
		pass

	func _show_message(_text: String) -> void:
		pass

	func _update_procedural_music() -> void:
		pass

	func _set_current_screen(screen_id: String) -> void:
		current_screen = screen_id

	func _queue_room_publication_check() -> void:
		pass

	func _autosave_foundation_run(_status_text: String = "Autosaved.", _force: bool = false) -> bool:
		saved_targets.append(run_state.current_world_node_id())
		return true


class RejectingGenerator extends "res://scripts/core/run_generator.gd":
	var install_attempts := 0
	var failure_snapshot_calls := 0
	var rejected_target := ""

	func _init(p_library: ContentLibrary) -> void:
		super(p_library)

	func travel_environment_result_with_caller_rollback(_run_state: RunState, _target_archetype_id: String, _target_prevalidated: bool = false) -> Dictionary:
		install_attempts += 1
		rejected_target = _target_archetype_id
		return {"ok": false, "errors": ["Roads-and-ride contract rejected destination installation."]}

	func environment_install_failure_snapshot() -> Dictionary:
		failure_snapshot_calls += 1
		return {"target_id": rejected_target, "scenario_id": "grand_casino_gala_night", "had_source": true, "errors": ["Roads-and-ride scenario publication rejected."]}


var library: ContentLibrary
var failures: Array = []
var assertions := 0
var grand_environment: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	library = ContentLibraryScript.new()
	var loaded: Dictionary = library.load(false)
	_expect(not (loaded.get("environment_archetypes", []) as Array).is_empty(), "Production content loads.")
	_check_definitions()
	if failures.is_empty():
		_check_ox_effect()
		_check_ox_cycle_and_persistence()
		_check_rafi_alternative_selection()
		_check_rafi_access_and_preview()
		_check_rafi_actual_transition()
		_check_rafi_rejection()
	for failure in failures:
		printerr("CHARACTER OFFERS ROADS AND RIDE: %s" % str(failure))
	print("CHARACTER OFFERS ROADS AND RIDE CHECK assertions=%d failures=%d ok=%s" % [assertions, failures.size(), str(failures.is_empty())])
	quit(0 if failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _definition(id: String) -> Dictionary:
	for value in OfferModel.definitions():
		var definition: Dictionary = value
		if str(definition.get("id", "")) == id:
			return definition
	return {}


func _check_definitions() -> void:
	var ox := _definition(OX_ID)
	var ride := _definition(RIDE_ID)
	var coffee := _definition(COFFEE_ID)
	_expect(not ox.is_empty() and not ride.is_empty(), "Both approved additional offers exist.")
	_expect(str(ox.get("character_id", "")) == "ox" and int(ox.get("chance_percent", -1)) == 20 and int(ox.get("minutes", -1)) == 15 and int(ox.get("cash_cost", -1)) == 0, "Ox preserves the approved canonical identity, chance and free fifteen-minute terms.")
	_expect(bool(ox.get("requires_no_route_scouting", false)) and bool((ox.get("flags_set", {}) as Dictionary).get("route_scouting_active", false)), "Ox uses existing route scouting only when it is absent.")
	_expect(str(ride.get("character_id", "")) == "rafi" and str(ride.get("ride_target_node_id", "")) == "grand_casino" and int(ride.get("chance_percent", -1)) == 20 and int(ride.get("cash_cost", -1)) == 5, "Rafi's alternative is a twenty-percent, five-dollar ride to the real Grand Casino.")
	_expect(int(coffee.get("alternative_priority", -1)) == 0 and int(ride.get("alternative_priority", -1)) > 0, "Coffee has priority when both Rafi alternatives are initially eligible.")


func _environment(archetype: String, minute: int) -> Dictionary:
	var rows: Array = []
	var seen := {}
	for value in OfferModel.definitions():
		var definition: Dictionary = value
		var binding: Variant = (definition.get("hosts", {}) as Dictionary).get(archetype, "")
		var host_ids: Array = binding if typeof(binding) == TYPE_ARRAY else [binding]
		for host_value in host_ids:
			var host_id := str(host_value)
			if host_id.is_empty() or seen.has(host_id):
				continue
			seen[host_id] = true
			rows.append({"instance_object_id": host_id, "presentation_object_id": host_id, "object_id": host_id, "family": "fixed", "object_type": "character", "active": true, "physical": true, "action_ids": []})
	return {"id": "roads_ride_fixture:%s" % archetype, "archetype_id": archetype, "world_node_id": archetype, "display_name": "Offer fixture %s" % archetype, "kind": "shop", "turns": 4, "entered_game_clock_minutes": minute, "visual_context": {}, "travel_lock_remaining": 0, "game_states": {}, "object_manifest": {"rows": rows}}


func _fresh(character: String, seed: String, minute: int = 720, venue: String = "") -> RunState:
	var run: RunState = RunStateScript.new()
	run.start_new(seed)
	run.game_clock_minutes = minute
	var archetype := venue if not venue.is_empty() else "bar" if character == "rafi" else "delta_queen"
	run.current_environment = _environment(archetype, minute)
	run.event_cadence_begin_visit(run.current_environment)
	run.inventory = ["bag"]
	run.initialize_home_from_profile(library.environment_archetype("apartment"), "apartment", {"tenure": {"type": "rent", "first_due_in_days": 7, "grace_days": 3}})
	return run


func _host_record(run: RunState, character: String) -> Dictionary:
	if character == "rafi":
		return {"manifest_object_id": "bar:bartender"}
	var binding: Variant = (_definition(OX_ID).get("hosts", {}) as Dictionary).get(str(run.current_environment.get("archetype_id", "")), "")
	var host_id := str(binding[0]) if typeof(binding) == TYPE_ARRAY and not binding.is_empty() else str(binding)
	return {"manifest_object_id": host_id}


func _choose(run: RunState, character: String, allow_ride: bool = true) -> Dictionary:
	return OfferModel.view_for_host(run, library, _host_record(run, character), func(offer: Dictionary) -> bool:
		return allow_ride if not str(offer.get("ride_target_node_id", "")).is_empty() else true
	)


func _record(run: RunState, character: String) -> Dictionary:
	return (run.narrative_flags.get(STATE_KEY, {}) as Dictionary).get(character, {})


func _winner(character: String, drunk: bool = false, minute: int = 720, venue: String = "") -> RunState:
	for index in range(64):
		var run := _fresh(character, "ROADS-RIDE-%02d" % index, minute, venue)
		run.drunk_level = 12 if drunk else 0
		if not _choose(run, character).is_empty():
			return run
	_expect(false, "Bounded deterministic seeds find an eligible %s offer." % character)
	return null


func _restore(run: RunState) -> RunState:
	var wire: Variant = JSON.parse_string(JSON.stringify(RunSaveCodecScript.encode(run.to_save_snapshot())))
	var restored: RunState = RunStateScript.new()
	restored.from_dict(RunSaveCodecScript.decode(wire as Dictionary))
	return restored


func _same_saved_record(expected: Dictionary, actual: Dictionary) -> bool:
	var value: Variant = actual.get("roll")
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or float(value) != floor(float(value)) or float(value) != float(expected.get("roll", -1)):
		return false
	var normalized := actual.duplicate(true)
	normalized["roll"] = int(value)
	return normalized == expected


func _check_ox_effect() -> void:
	var run := _winner("ox")
	if run == null:
		return
	var offer := _choose(run, "ox")
	var clock := run.game_clock_minutes
	var cash := run.bankroll
	var items := run.inventory.duplicate(true)
	var home := run.home_state.duplicate(true)
	var turns := int(run.current_environment.get("turns", 0))
	var actions := int(run.event_cadence.get("action_index", 0))
	var flags := run.narrative_flags.duplicate(true)
	var locked_route := library.route("grand_casino")
	var before_access := run.travel_route_status(locked_route)
	var result := OfferModel.resolve(run, library, OX_ID, offer.get("token", {}), true)
	_expect(bool(result.get("ok", false)) and run.game_clock_minutes == clock + 15 and run.bankroll == cash, "Ox is free and advances exactly fifteen canonical minutes.")
	_expect(run.travel_scouting_level() == 1 and bool(run.narrative_flags.get("route_scouting_active", false)), "Ox grants the existing route-scouting flag and effect.")
	_expect(run.inventory == items and run.home_state == home and run.travel_option_bonus() == 0, "Ox grants no item, home change or extra route choice.")
	_expect(int(run.current_environment.get("turns", 0)) == turns and int(run.event_cadence.get("action_index", 0)) == actions, "Ox creates no action turns or default time charge.")
	var after_access := run.travel_route_status(locked_route)
	_expect(bool(after_access.get("available", true)) == bool(before_access.get("available", false)) and bool(run.narrative_flags.get("grand_casino_invite", false)) == bool(flags.get("grand_casino_invite", false)), "Ox's route details cannot bypass the Grand Casino's invitation or progression requirements.")
	var retry := OfferModel.resolve(run, library, OX_ID, offer.get("token", {}), true)
	_expect(not bool(retry.get("ok", false)) and run.game_clock_minutes == clock + 15, "Ox's accepted callback applies once.")
	var restored := _restore(run)
	_expect(restored.travel_scouting_level() == 1 and str(_record(restored, "ox").get("status", "")) == "accepted", "Ox's existing scouting effect and consumed claim survive save-load.")
	run.advance_game_clock_minutes(1440)
	run.set_environment(_environment("motel", run.game_clock_minutes))
	_expect(run.travel_scouting_level() == 1, "Ox preserves the existing scouting duration across time, day rollover and travel.")
	var item_scout := _winner("ox")
	if item_scout != null:
		item_scout.add_item("roadside_map")
		_expect(_choose(item_scout, "ox").is_empty(), "Existing passive item scouting excludes Ox's redundant offer.")
	var service_scout := _winner("ox")
	if service_scout != null:
		service_scout.narrative_flags["route_scouting_active"] = true
		_expect(_choose(service_scout, "ox").is_empty(), "Existing service scouting excludes Ox's redundant offer.")


func _check_ox_cycle_and_persistence() -> void:
	for index in range(8):
		var run := _fresh("ox", "OX-PERSIST-%02d" % index)
		_choose(run, "ox")
		var remembered := _record(run, "ox").duplicate(true)
		var rng := run.rng_state
		_choose(run, "ox")
		var restored := _restore(run)
		_choose(restored, "ox")
		_expect(_same_saved_record(remembered, _record(restored, "ox")) and run.rng_state == rng, "Ox's exact shared roll/decision persists through reload without game-RNG consumption.")
	var first := _fresh("ox", "OX-SHARED-ROLL", 720, "small_underground_casino")
	var twin := _fresh("ox", "OX-SHARED-ROLL", 720, "delta_queen")
	_choose(first, "ox")
	_choose(twin, "ox")
	_expect(_record(first, "ox").get("cycle_id") == _record(twin, "ox").get("cycle_id") and _record(first, "ox").get("roll") == _record(twin, "ox").get("roll"), "Ox has one game-day roll across Punchline and Delta Queen.")
	var departure := _winner("ox")
	if departure != null:
		var original := departure.current_environment.duplicate(true)
		departure.set_environment(_environment("motel", departure.game_clock_minutes))
		departure.set_environment(original)
		_expect(_choose(departure, "ox").is_empty(), "Departing expires Ox's unclaimed offer for the cycle.")
	var midnight := _winner("ox", false, 1430)
	if midnight != null:
		var cycle := str(_record(midnight, "ox").get("cycle_id", ""))
		midnight.advance_game_clock_minutes(11)
		_choose(midnight, "ox")
		_expect(str(_record(midnight, "ox").get("cycle_id", "")) != cycle, "Ox rotates his shared cycle at the game-day boundary.")


func _check_rafi_alternative_selection() -> void:
	var coffee := _winner("rafi", true)
	if coffee != null:
		var chosen := _choose(coffee, "rafi")
		_expect(str(chosen.get("id", "")) == COFFEE_ID, "Coffee has first-eligible priority when both Rafi alternatives qualify.")
		var record := _record(coffee, "rafi").duplicate(true)
		coffee.drunk_level = 0
		_expect(_choose(coffee, "rafi").is_empty() and _record(coffee, "rafi").get("offer_id") == record.get("offer_id"), "Removing Drunk cannot switch a saved coffee decision to a ride.")
		coffee.drunk_level = 12
		var current := _choose(coffee, "rafi")
		OfferModel.resolve(coffee, library, COFFEE_ID, current.get("token", {}), false)
		coffee.drunk_level = 0
		_expect(_choose(coffee, "rafi").is_empty(), "Declining coffee consumes Rafi's single canonical decision.")
	var ride := _winner("rafi")
	if ride != null:
		var chosen := _choose(ride, "rafi")
		_expect(str(chosen.get("id", "")) == RIDE_ID, "A sober player can receive the eligible alternative ride.")
		var remembered := _record(ride, "rafi").duplicate(true)
		ride.drunk_level = 12
		_expect(str(_choose(ride, "rafi").get("id", "")) == RIDE_ID and _record(ride, "rafi").get("roll") == remembered.get("roll"), "Later Drunk cannot switch the saved ride decision to coffee or reroll it.")
		var restored := _restore(ride)
		_expect(str(_choose(restored, "rafi").get("id", "")) == RIDE_ID and _same_saved_record(remembered, _record(restored, "rafi")), "Rafi's chosen alternative persists across JSON reload.")


func _grand_fixture(run: RunState) -> void:
	if grand_environment.is_empty():
		grand_environment = EnvironmentInstanceScript.from_archetype(library.environment_archetype("grand_casino"), 2, run.create_rng("grand_ride_fixture"), library).to_dict()
		grand_environment["world_node_id"] = "grand_casino"
	run.world_map = WorldMapScript.normalize({
		"version": 3, "start_node_id": "apartment", "current_node_id": "bar", "visited_path": ["apartment", "bar"],
		"nodes": [
			{"id": "bar", "archetype_id": "bar", "label": "Bar", "kind": "bar", "state": "visited", "seen": true},
			{"id": "grand_casino", "archetype_id": "grand_casino", "label": "Grand Casino", "kind": "casino", "state": "visited", "seen": true, "environment": grand_environment.duplicate(true)},
			{"id": "apartment", "archetype_id": "apartment", "label": "Home", "kind": "home", "state": "visited", "seen": true},
		],
		"edges": [{"a": "bar", "b": "grand_casino", "distance_blocks": 8, "base_cost": 70, "cost": 70}, {"a": "bar", "b": "apartment", "distance_blocks": 2}],
	})
	run.environment_history = [{"id": "previous_fixture", "archetype_id": "apartment", "world_node_id": "apartment", "display_name": "Home", "kind": "home"}]
	run.narrative_flags["grand_casino_invite"] = true
	run.current_environment["world_map_travel"] = true
	run.current_environment["travel_hooks"] = ["grand_casino", "apartment"]
	run.current_environment["next_archetypes"] = ["grand_casino", "apartment"]


func _ride_host(run: RunState, reject_install: bool = false) -> RideHost:
	var host := RideHost.new()
	host.library = library
	host.run_state = run
	host.generator = RejectingGenerator.new(library) if reject_install else RunGeneratorScript.new(library)
	for field in host.RUN_UI_SCRIPT_PATHS:
		host.set(str(field), load(str(host.RUN_UI_SCRIPT_PATHS[field])))
	host.current_screen = host.SCREEN_ENVIRONMENT
	return host


func _choose_production(host: RideHost) -> Dictionary:
	var offer := OfferModel.view_for_host(host.run_state, library, _host_record(host.run_state, "rafi"), func(candidate: Dictionary) -> bool:
		return not host._character_offer_route_preview(candidate).is_empty() if not str(candidate.get("ride_target_node_id", "")).is_empty() else true
	)
	if not str(offer.get("ride_target_node_id", "")).is_empty() and host._character_offer_route_preview(offer).is_empty():
		return {}
	return offer


func _popup(host: RideHost, offer: Dictionary, preview: Dictionary) -> void:
	host.pending_event_choice_popup_snapshot = {"popup_type": "character_offer", "offer_id": RIDE_ID, "token": offer.get("token", {}), "route_preview": preview}


func _check_rafi_access_and_preview() -> void:
	var winning := _winner("rafi")
	if winning == null:
		return
	for blocked_by in ["invitation", "hidden", "progression", "travel_lock", "cash"]:
		var run := _fresh("rafi", winning.seed_text)
		_grand_fixture(run)
		match blocked_by:
			"invitation": run.narrative_flags["grand_casino_invite"] = false
			"hidden":
				var nodes: Array = run.world_map.get("nodes", [])
				for index in range(nodes.size()):
					if str((nodes[index] as Dictionary).get("id", "")) == "grand_casino":
						nodes[index]["state"] = "hidden"
						nodes[index]["seen"] = false
						nodes[index]["unlocked"] = false
					run.world_map["nodes"] = nodes
			"progression": run.environment_history = []
			"travel_lock": run.current_environment["travel_lock_remaining"] = 1
			"cash": run.bankroll = 4
		var host := _ride_host(run)
		var offer := _choose_production(host)
		_expect(offer.is_empty() and host._character_offer_route_preview(_definition(RIDE_ID)).is_empty(), "Rafi's ride cannot bypass %s eligibility." % blocked_by)
		_expect(str(_record(run, "rafi").get("offer_id", "")) == "", "An ineligible ride preserves Rafi's unbound saved decision (%s)." % blocked_by)
		host.free()
	var pending := _fresh("rafi", winning.seed_text)
	_grand_fixture(pending)
	pending.narrative_flags["grand_casino_invite"] = false
	var pending_host := _ride_host(pending)
	_choose_production(pending_host)
	var roll: Variant = _record(pending, "rafi").get("roll")
	pending.narrative_flags["grand_casino_invite"] = true
	var eligible := _choose_production(pending_host)
	_expect(str(eligible.get("id", "")) == RIDE_ID and _record(pending, "rafi").get("roll") == roll, "New route eligibility can bind the same winning Rafi roll without another roll.")
	var preview: Dictionary = pending_host._character_offer_route_preview(eligible)
	var normal_route := pending_host.generator.world_route_for_target(pending, "grand_casino")
	_expect(str(preview.get("target_node_id", "")) == "grand_casino" and str(preview.get("target_name", "")) == "Grand Casino" and int(preview.get("fare", -1)) == 5, "Rafi's quote identifies the actual target and complete five-dollar fare.")
	_expect(int(preview.get("wait_minutes", -1)) == 0 and int(preview.get("travel_minutes", -1)) == pending_host._travel_clock_minutes_for_route(normal_route) and int(preview.get("arrival_game_clock_minutes", -1)) == pending.game_clock_minutes + int(preview.get("travel_minutes", 0)), "Rafi preserves the normal route duration and adds no wait or action time.")
	_expect(str(preview.get("summary", "")).contains("$5") and str(preview.get("summary", "")).contains("Depart:") and str(preview.get("summary", "")).contains("Arrive:"), "Rafi discloses total fare, departure, travel and arrival before acceptance.")
	pending_host.free()


func _check_rafi_actual_transition() -> void:
	var source := _winner("rafi")
	if source == null:
		return
	var run := _fresh("rafi", source.seed_text)
	_grand_fixture(run)
	run.bankroll = 5
	run.narrative_flags["crew_rook_ride_active"] = true
	run.narrative_flags["crew_rook_ride_discount_percent"] = 50
	var host := _ride_host(run)
	var offer := _choose_production(host)
	_expect(str(offer.get("id", "")) == RIDE_ID, "The real route callback selects Rafi's exact-cash ride.")
	if offer.is_empty():
		host.free()
		return
	var preview: Dictionary = host._character_offer_route_preview(offer)
	var clock := run.game_clock_minutes
	var actions := int(run.event_cadence.get("action_index", 0))
	_popup(host, offer, preview)
	var accepted: Dictionary = host._resolve_character_offer_response(RIDE_ID, offer.get("token", {}), true)
	_expect(bool(accepted.get("ok", false)) and run.current_world_node_id() == "grand_casino", "The production Rafi response installs and arrives at the actual Grand Casino.")
	_expect(run.bankroll == 0 and run.game_clock_minutes == clock + int(preview.get("travel_minutes", 0)), "Rafi charges exactly five dollars once, including with an ordinary Rook fare modifier, and applies normal travel time.")
	_expect(int(run.event_cadence.get("action_index", 0)) == actions, "Rafi's ride invents no action turns.")
	_expect(not host.saved_targets.is_empty() and str(host.saved_targets[0]) == "grand_casino" and str(_record(run, "rafi").get("status", "")) == "accepted", "The accepted ride is saved only after the correct destination is committed.")
	var before_cash := run.bankroll
	var before_clock := run.game_clock_minutes
	var repeated: Dictionary = host._resolve_character_offer_response(RIDE_ID, offer.get("token", {}), true)
	_expect(not bool(repeated.get("ok", false)) and run.bankroll == before_cash and run.game_clock_minutes == before_clock, "A stale Rafi callback cannot pay or travel twice.")
	var restored := _restore(run)
	_expect(str(_record(restored, "rafi").get("status", "")) == "accepted" and restored.current_world_node_id() == "grand_casino", "Rafi's completed ride and claim survive JSON save-load.")
	host.free()


func _check_rafi_rejection() -> void:
	var source := _winner("rafi")
	if source == null:
		return
	for rejection_kind in ["install", "stale_access", "stale_cash"]:
		var run := _fresh("rafi", source.seed_text)
		_grand_fixture(run)
		var host := _ride_host(run, rejection_kind == "install")
		var offer := _choose_production(host)
		var preview: Dictionary = host._character_offer_route_preview(offer)
		_expect(not offer.is_empty() and not preview.is_empty(), "A valid quote exists before the %s rejection test." % rejection_kind)
		_popup(host, offer, preview)
		if rejection_kind == "stale_access":
			run.narrative_flags["grand_casino_invite"] = false
		elif rejection_kind == "stale_cash":
			run.bankroll = 4
		var before := run.to_dict()
		var rejected: Dictionary = host._resolve_character_offer_response(RIDE_ID, offer.get("token", {}), true)
		_expect(not bool(rejected.get("ok", false)) and run.to_dict() == before and host.saved_targets.is_empty(), "Rejected %s restores the Rafi claim, money, clock and run state with no autosave." % rejection_kind)
		if rejection_kind == "install":
			_expect(host.generator is RejectingGenerator and (host.generator as RejectingGenerator).install_attempts == 1 and (host.generator as RejectingGenerator).failure_snapshot_calls == 0, "An offered ride skips the otherwise eligible scenario-suppression retry instead of replaying travel without its claim.")
		host.free()
