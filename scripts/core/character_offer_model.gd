class_name CharacterOfferModel
extends RefCounted

# Optional attributes on existing physical characters. Content owns bindings and
# effects; RunState owns rolls, claims, time, inventory and money. No game RNG or
# action boundary is consumed by discovering, reviewing or resolving an offer.
const Hours := preload("res://scripts/core/environment_hours.gd")
const Rng := preload("res://scripts/core/rng_stream.gd")
const STATE_KEY := "character_offer_cycles"
const DATA_PATH := "res://data/environments/character_offers.json"
const ARCHETYPES_PATH := "res://data/environments/archetypes.json"

static var _definitions: Array = []
static var _archetypes: Dictionary = {}


static func definitions() -> Array:
	return _definitions_readonly().duplicate(true)


# Optional eligibility can change without a room turn. Bind the lightweight
# decorated-view cache, while retaining the expensive sealed room catalog.
static func interaction_cache_stamp(run_state: RunState) -> int:
	if run_state == null:
		return 0
	var has_host := false
	var route_dependencies: Array = []
	for offer in _definitions_readonly():
		if not _host_id(offer, run_state.current_environment).is_empty():
			has_host = true
			if bool(offer.get("free_home_ride", false)):
				route_dependencies = [run_state.narrative_flags, run_state.active_delivery_run,
					run_state.rng_state, run_state.unlocked_travel, run_state.closing_time_state,
					int(run_state.world_map.get("revision", 0))]
	if not has_host:
		return 0
	return hash([
		run_state.game_clock_minutes, run_state.is_terminal(),
		run_state.bankroll, run_state.suspicion_level(), run_state.drunk_level,
		run_state.pending_drunk_absorption_amount(), run_state.inventory,
		run_state.debt, run_state.home_state,
		_dict(run_state.narrative_flags.get(STATE_KEY, {})), route_dependencies,
	])


# Background cabinets patch their own objects without refreshing the room.
# Only an offer's visible presence requires a new character-card projection;
# ordinary time/meter movement keeps the same button and its live dispatch.
static func visible_cache_stamp(run_state: RunState, library: ContentLibrary) -> int:
	if run_state == null or library == null:
		return 0
	var has_host := false
	var visible: Array = []
	for offer in _definitions_readonly():
		if _host_id(offer, run_state.current_environment).is_empty():
			continue
		has_host = true
		var current := view(run_state, library, str(offer.get("id", "")))
		if not current.is_empty():
			visible.append(str(current.get("id", "")))
		if bool(offer.get("free_home_ride", false)):
			visible.append(hash([run_state.home_state, run_state.unlocked_travel,
				int(run_state.world_map.get("revision", 0))]))
	return hash(visible) if has_host else 0


static func _definitions_readonly() -> Array:
	if _definitions.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if typeof(parsed) == TYPE_ARRAY:
			_definitions = parsed
	return _definitions


static func _archetype(id: String) -> Dictionary:
	if _archetypes.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARCHETYPES_PATH))
		if typeof(parsed) == TYPE_ARRAY:
			for value in parsed:
				if typeof(value) == TYPE_DICTIONARY:
					_archetypes[str(value.get("id", ""))] = value
	return _dict(_archetypes.get(id, {}))


static func _cycle_archetype(offer: Dictionary) -> Dictionary:
	if offer.has("cycle_hours"):
		return {"open_hours": _dict(offer.get("cycle_hours"))}
	return _archetype(str(offer.get("cycle_archetype_id", "")))


static func _visit_id(run_state: RunState) -> String:
	return "%s#%d" % [str(run_state.current_environment.get("id", "")), run_state.environment_travel_count()]


static func _host_ids(offer: Dictionary, environment: Dictionary) -> Array:
	var value: Variant = _dict(offer.get("hosts", {})).get(str(environment.get("archetype_id", "")), "")
	if typeof(value) == TYPE_ARRAY:
		return value
	return [] if str(value).is_empty() else [str(value)]


static func _host_id(offer: Dictionary, environment: Dictionary) -> String:
	var expected := _host_ids(offer, environment)
	for value in _dict(environment.get("object_manifest", {})).get("rows", []):
		var row := _dict(value)
		var id := str(row.get("instance_object_id", row.get("object_id", "")))
		if id in expected and bool(row.get("active", true)) and bool(row.get("physical", true)):
			return id
	return ""


static func _present(offer: Dictionary, environment: Dictionary) -> bool:
	return not _host_id(offer, environment).is_empty()


static func _character_definitions() -> Dictionary:
	var characters := {}
	for offer in _definitions_readonly():
		var character_id := str(offer.get("character_id", ""))
		if not characters.has(character_id):
			characters[character_id] = []
		characters[character_id].append(offer)
	return characters


# Remember failed rolls too. Eligibility changes within a visit never reroll.
# Each canonical character has one bounded record, including Dot's shared cycle.
static func synchronize(run_state: RunState) -> void:
	if run_state == null or run_state.current_environment.is_empty():
		return
	var previous := _dict(run_state.narrative_flags.get(STATE_KEY, {}))
	var cycles := previous.duplicate(true)
	var now := run_state.game_clock_minutes
	var characters := _character_definitions()
	for character_id in characters:
		var offers: Array = characters[character_id]
		var offer: Dictionary = offers[0]
		var cycle := Hours.operating_cycle_id(_cycle_archetype(offer), now)
		var state := _dict(cycles.get(character_id, {})).duplicate(true)
		var present := false
		for alternative in offers:
			if _present(alternative, run_state.current_environment):
				present = true
				break
		var venue := _archetype(str(run_state.current_environment.get("archetype_id", "")))
		var open := Hours.environment_open_at(venue, now % 1440)
		if str(state.get("status", "")) == "available" and (
				str(state.get("cycle_id", "")) != cycle \
				or str(state.get("visit_id", "")) != _visit_id(run_state) \
				or not present or not open):
			state["status"] = "expired"
		if present and open and str(state.get("cycle_id", "")) != cycle and not run_state.is_terminal():
			var rng := Rng.new()
			rng.configure(Rng.derive_seed(run_state.seed_value, run_state.seed_value, "character_offer:%s:%s" % [character_id, cycle]))
			var roll := rng.randi_range(1, 100)
			state = {
				"offer_id": str(offer.get("id", "")) if offers.size() == 1 else "", "cycle_id": cycle,
				"roll": roll, "status": "available" if roll <= int(offer.get("chance_percent", 0)) else "missed",
				"visit_id": _visit_id(run_state),
			}
		if not state.is_empty():
			cycles[character_id] = state
	# Replace nested values rather than mutating an in-flight save snapshot.
	if cycles != previous:
		run_state.narrative_flags[STATE_KEY] = cycles


static func expire_departure(run_state: RunState) -> void:
	var previous := _dict(run_state.narrative_flags.get(STATE_KEY, {}))
	var cycles := previous.duplicate(true)
	for character_id in cycles:
		var state := _dict(cycles[character_id])
		if str(state.get("status", "")) == "available":
			state["status"] = "expired"
			cycles[character_id] = state
	if cycles != previous:
		run_state.narrative_flags[STATE_KEY] = cycles


# Host-candidate publication preserves live aliases in narrative_flags. A worker
# save must own these small nested records even when publication updates aliases.
static func snapshot_flags(flags: Dictionary) -> Dictionary:
	var result := flags.duplicate(false)
	if flags.has(STATE_KEY):
		result[STATE_KEY] = _dict(flags[STATE_KEY]).duplicate(true)
	return result


static func view_for_host(run_state: RunState, library: ContentLibrary, host: Dictionary, offer_eligibility: Callable = Callable()) -> Dictionary:
	if not _can_view(run_state, library):
		return {}
	synchronize(run_state)
	_select_for_host(run_state, library, host, offer_eligibility)
	for offer in _definitions_readonly():
		if str(host.get("manifest_object_id", "")) in _host_ids(offer, run_state.current_environment):
			var result := view(run_state, library, str(offer.get("id", "")))
			if not result.is_empty():
				return result
	return {}


static func _can_view(run_state: RunState, library: ContentLibrary) -> bool:
	return run_state != null and library != null and not run_state.is_terminal() and not run_state.is_tutorial_run() \
			and not bool(run_state.current_environment.get("environment_test", false))


# Alternatives share a roll and claim. Bind once to the first eligible content
# entry, using priority to preserve existing services. Route offers require an
# authoritative UI route preview before they can consume that daily decision.
static func _select_for_host(run_state: RunState, library: ContentLibrary, host: Dictionary, offer_eligibility: Callable = Callable()) -> void:
	var alternatives: Array = []
	for offer in _definitions_readonly():
		if str(host.get("manifest_object_id", "")) in _host_ids(offer, run_state.current_environment):
			alternatives.append(offer)
	alternatives.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("alternative_priority", 0)) < int(b.get("alternative_priority", 0)))
	for offer in alternatives:
		var character_id := str(offer.get("character_id", ""))
		var state := _dict(_dict(run_state.narrative_flags.get(STATE_KEY, {})).get(character_id, {}))
		if str(state.get("status", "")) != "available" or not str(state.get("offer_id", "")).is_empty():
			continue
		if not _eligible(run_state, offer) or not _grant_exists(library, offer):
			continue
		if not str(offer.get("ride_target_node_id", "")).is_empty() and not offer_eligibility.is_valid():
			continue
		if offer_eligibility.is_valid() and not bool(offer_eligibility.call(offer)):
			continue
		var cycles := _dict(run_state.narrative_flags.get(STATE_KEY, {})).duplicate(true)
		state = state.duplicate(true)
		state["offer_id"] = str(offer.get("id", ""))
		cycles[character_id] = state
		run_state.narrative_flags[STATE_KEY] = cycles
		return


static func _grant_exists(library: ContentLibrary, offer: Dictionary) -> bool:
	var item_id := str(offer.get("inventory_add_item_id", ""))
	return item_id.is_empty() or not library.item(item_id).is_empty()


static func view(run_state: RunState, library: ContentLibrary, offer_id: String) -> Dictionary:
	if not _can_view(run_state, library):
		return {}
	synchronize(run_state)
	for offer in _definitions_readonly():
		if str(offer.get("id", "")) != offer_id:
			continue
		_select_for_host(run_state, library, {"manifest_object_id": _host_id(offer, run_state.current_environment)})
		var state := _dict(_dict(run_state.narrative_flags.get(STATE_KEY, {})).get(str(offer.get("character_id", "")), {}))
		if str(state.get("status", "")) != "available" or str(state.get("offer_id", "")) != offer_id or not _eligible(run_state, offer):
			return {}
		if not _grant_exists(library, offer):
			return {}
		var result: Dictionary = offer.duplicate(true)
		result["token"] = {
			"offer_id": offer_id, "cycle_id": str(state.get("cycle_id", "")),
			"visit_id": _visit_id(run_state), "game_clock_minutes": run_state.game_clock_minutes,
			"state_stamp": hash([run_state.bankroll, run_state.suspicion_level(), run_state.drunk_level,
				run_state.pending_drunk_absorption_amount(), run_state.inventory, run_state.debt, run_state.home_state]),
		}
		result["summary"] = _summary(run_state, offer)
		return result
	return {}


static func _eligible(run_state: RunState, offer: Dictionary) -> bool:
	if not _present(offer, run_state.current_environment):
		return false
	var minute := run_state.game_minute_of_day()
	var hours := Hours.status_at(_archetype(str(run_state.current_environment.get("archetype_id", ""))), minute)
	if not bool(hours.get("open", false)) \
			or int(hours.get("minutes_until_close", 0)) < int(offer.get("minimum_minutes_before_close", 0)) \
			or run_state.bankroll < int(offer.get("cash_cost", 0)) \
			or run_state.suspicion_level() < int(offer.get("min_heat", 0)):
		return false
	if bool(offer.get("requires_alcohol", false)) and run_state.drunk_level <= 0 and run_state.pending_drunk_absorption_amount() <= 0:
		return false
	var item_id := str(offer.get("required_item_id", ""))
	if not item_id.is_empty() and run_state.available_carried_item_index(item_id) < 0:
		return false
	var excluded_item_id := str(offer.get("excluded_carried_item_id", ""))
	if not excluded_item_id.is_empty() and run_state.carries_item(excluded_item_id):
		return false
	if bool(offer.get("requires_no_route_scouting", false)) and run_state.travel_scouting_level() > 0:
		return false
	if bool(offer.get("free_home_ride", false)):
		if not run_state.home_is_active() or str(run_state.home_state.get("home_node_id", "")).is_empty():
			return false
		if minute < int(offer.get("window_start_minute", 0)) and minute >= int(offer.get("shift_end_minute", 0)):
			return false
	return true


static func _summary(run_state: RunState, offer: Dictionary) -> String:
	if bool(offer.get("free_home_ride", false)):
		return "Free ride to your active home. Fare: $0. Normal route travel time applies."
	if not str(offer.get("ride_target_node_id", "")).is_empty():
		return "Total fare: $%d. Normal route travel time applies." % int(offer.get("cash_cost", 0))
	var lines: Array[String] = []
	var cost := int(offer.get("cash_cost", 0))
	lines.append("Cost: $%d. Time: %d minutes." % [cost, int(offer.get("minutes", 0))])
	var reward := int(offer.get("cash_reward", 0))
	if reward > 0:
		lines.append("Receive $%d after the time passes." % reward)
	if int(offer.get("drunk_reduction", 0)) > 0:
		lines.append("Reduce Drunk by up to %d and pending alcohol by up to %d." % [int(offer.get("drunk_reduction")), int(offer.get("pending_reduction", 0))])
	if int(offer.get("heat_reduction", 0)) > 0:
		lines.append("Reduce Heat by up to %d, to a minimum of 0." % int(offer.get("heat_reduction")))
	if not str(offer.get("item_summary", "")).is_empty():
		lines.append(str(offer.get("item_summary")))
	if not str(offer.get("item_gain_summary", "")).is_empty():
		lines.append(str(offer.get("item_gain_summary")))
	if not str(offer.get("effect_summary", "")).is_empty():
		lines.append(str(offer.get("effect_summary")))
	lines.append("Stay at %s." % str(run_state.current_environment.get("display_name", "this venue")))
	return "\n".join(lines)


static func _finish(run_state: RunState, offer: Dictionary, status: String) -> void:
	var cycles := _dict(run_state.narrative_flags.get(STATE_KEY, {})).duplicate(true)
	var character_id := str(offer.get("character_id", ""))
	var state := _dict(cycles.get(character_id, {})).duplicate(true)
	state["status"] = status
	cycles[character_id] = state
	run_state.narrative_flags[STATE_KEY] = cycles


# The ride caller owns one lifecycle transaction spanning claim, wait and travel.
static func claim(run_state: RunState, library: ContentLibrary, offer_id: String, token: Dictionary) -> Dictionary:
	var current := view(run_state, library, offer_id)
	if current.is_empty() or token != _dict(current.get("token", {})):
		return _error("That offer changed or expired. Review it again.")
	_finish(run_state, current, "accepted")
	return {"ok": true, "offer": current, "messages": [], "errors": []}


static func resolve(run_state: RunState, library: ContentLibrary, offer_id: String, token: Dictionary, accept: bool) -> Dictionary:
	var current := view(run_state, library, offer_id)
	if current.is_empty() or token != _dict(current.get("token", {})):
		return _error("That offer changed or expired. Review it again.")
	if not accept:
		_finish(run_state, current, "declined")
		return {"ok": true, "type": "character_offer", "offer_id": offer_id, "minutes": 0, "message": "Offer declined.", "messages": [], "errors": []}
	if bool(current.get("free_home_ride", false)) or not str(current.get("ride_target_node_id", "")).is_empty():
		return _error("Review the actual route before accepting this ride.")
	var candidate := run_state.detached_host_action_candidate()
	if candidate == null:
		return _error("The offer could not create a safe transaction.")
	_finish(candidate, current, "accepted")
	var item_id := str(current.get("required_item_id", ""))
	if not item_id.is_empty() and not candidate.remove_available_carried_item(item_id):
		return _error("That carried item is no longer available.")
	var cost := int(current.get("cash_cost", 0))
	if cost > 0:
		candidate.change_bankroll(-cost, true)
	var minutes := int(current.get("minutes", 0))
	var clock := candidate.advance_game_clock_minutes(minutes)
	if not bool(clock.get("ok", false)) or not bool(clock.get("applied", false)):
		return _error("The offer could not advance time safely.", clock.get("errors", []))
	var granted_item_id := str(current.get("inventory_add_item_id", ""))
	if not granted_item_id.is_empty():
		if candidate.carries_item(granted_item_id):
			return _error("That item is already carried. Review the current offer again.")
		candidate.add_item(granted_item_id)
	for flag in _dict(current.get("flags_set", {})):
		candidate.narrative_flags[str(flag)] = current["flags_set"][flag]
	candidate.recover_alcohol(int(current.get("drunk_reduction", 0)), int(current.get("pending_reduction", 0)))
	var heat := candidate.recover_heat(int(current.get("heat_reduction", 0)), "character_offer:%s" % offer_id)
	if not bool(heat.get("ok", false)) and not bool(heat.get("inactive", false)):
		return _error("The offer could not apply its Heat consequence safely.", heat.get("errors", []))
	var reward := int(current.get("cash_reward", 0))
	if reward > 0:
		candidate.change_bankroll(reward, true)
	var message := "%s completed (%d minutes)." % [str(current.get("label", "Offer")), minutes]
	candidate.log_story({"type": "character_offer", "offer_id": offer_id, "character_id": str(current.get("character_id", "")), "minutes": minutes, "cash_cost": cost, "cash_reward": reward, "inventory_remove_item_id": item_id, "inventory_add_item_id": granted_item_id, "message": message})
	var facts := candidate.scenario_flush_facts()
	if not bool(facts.get("ok", false)) and not bool(facts.get("inactive", false)):
		return _error("The offer's room consequences could not settle safely.", facts.get("errors", []))
	candidate.evaluate_immediate_terminal_state(false)
	if not run_state.publish_host_action_candidate(candidate):
		return _error("The completed offer could not be published.")
	return {"ok": true, "type": "character_offer", "offer_id": offer_id, "minutes": minutes, "message": message, "messages": [message], "errors": []}


static func _error(message: String, errors: Array = []) -> Dictionary:
	return {"ok": false, "message": message, "messages": [message], "errors": errors}


static func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}
