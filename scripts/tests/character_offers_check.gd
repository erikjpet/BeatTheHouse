extends SceneTree

# Focused optional-offer contract. No rendered scene or game loop is started.
# Run with: godot --headless --path . --script res://scripts/tests/character_offers_check.gd

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const RunSaveCodecScript := preload("res://scripts/core/run_save_codec.gd")
const DeliveryRunModelScript := preload("res://scripts/core/delivery_run_model.gd")
const CharacterOfferModelScript := preload("res://scripts/core/character_offer_model.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const WorldMapScript := preload("res://scripts/core/world_map.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")


# This harness runs the production acceptance and travel methods. Only visible
# presentation and disk writes are replaced; no clock, route, claim, generation,
# inventory or consequence authority is mocked on the successful path.
class IrisHost extends "res://scripts/ui/foundation_main.gd":
	var saved_home_ids: Array = []

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
		saved_home_ids.append(run_state.current_world_node_id())
		return true


class RejectingTravelGenerator extends "res://scripts/core/run_generator.gd":
	func _init(p_library: ContentLibrary) -> void:
		super(p_library)

	func travel_environment_result_with_caller_rollback(_run_state: RunState, _target_archetype_id: String, _target_prevalidated: bool = false) -> Dictionary:
		return {"ok": false, "errors": ["Offer contract injected destination-install rejection."]}


class RejectingHeatRun extends "res://scripts/core/run_state.gd":
	func scenario_enqueue_fact(fact_type: String, producer: String, payload: Dictionary = {}, fact_id: String = "", node_id: String = "") -> Dictionary:
		if fact_type in ["heat_changed", "heat_band_changed"]:
			return {"ok": false, "errors": ["Offer contract injected heat-fact rejection."]}
		return super.scenario_enqueue_fact(fact_type, producer, payload, fact_id, node_id)


class RejectingFlushRun extends "res://scripts/core/run_state.gd":
	func scenario_flush_facts(_boundary_serial: int = -1) -> Dictionary:
		return {"ok": false, "errors": ["Offer contract injected fact-flush rejection."]}

const OFFER_IDS := {
	"iris": "iris_shift_ride",
	"rafi": "rafi_last_coffee",
	"marco": "marco_extra_hands",
	"lena": "lena_buying_shades",
	"dot": "dot_quiet_company",
}
const STATE_KEY := "character_offer_cycles"

var library: ContentLibrary
var failures: Array = []
var assertions := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	library = ContentLibraryScript.new()
	var loaded: Dictionary = library.load(false)
	_expect(not (loaded.get("environment_archetypes", []) as Array).is_empty(), "Production content loads for offer checks.")
	if not failures.is_empty():
		_finish()
		return
	_check_authored_offers()
	_check_rolls_and_save_persistence()
	_check_decline_and_departure()
	_check_operating_cycles()
	_check_marco_transition()
	_check_coffee_transition()
	_check_lena_transition()
	_check_dot_transition()
	_check_stale_selection()
	_check_clock_consequences()
	_check_rejected_consequences()
	_check_iris_preview_and_transition()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr("CHARACTER OFFERS: %s" % str(failure))
	print("CHARACTER OFFERS CHECK assertions=%d failures=%d ok=%s" % [assertions, failures.size(), str(failures.is_empty())])
	quit(0 if failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _definition(character_id: String) -> Dictionary:
	for value in CharacterOfferModelScript.definitions():
		var definition: Dictionary = value
		if str(definition.get("character_id", "")) == character_id:
			return definition
	return {}


func _check_authored_offers() -> void:
	_expect(CharacterOfferModelScript.definitions().size() == 5, "The approved first batch contains five offer definitions.")
	var expected_chances := {"iris": 25, "rafi": 20, "marco": 25, "lena": 20, "dot": 20}
	var exact_dialogue := {
		"iris": "I’m off at 05:00. Wait for me and I’ll drive you home. No charge.",
		"rafi": "Last of the fresh pot. Three dollars and ten minutes. It’ll clear your head a little.",
		"marco": "Help me carry these bags upstairs? Twenty minutes. Six dollars.",
		"lena": "Lost my sunglasses. Nine dollars for yours, if you’re selling.",
		"dot": "I’ve got a quiet corner. Sit with me a while. Give the room someone else to watch.",
	}
	for character in OFFER_IDS:
		var definition := _definition(str(character))
		_expect(str(definition.get("id", "")) == str(OFFER_IDS[character]), "Canonical offer identity exists for %s." % character)
		_expect(int(definition.get("chance_percent", -1)) == int(expected_chances[character]), "Approved probability is preserved for %s." % character)
		_expect(str(definition.get("dialogue", "")) == str(exact_dialogue[character]), "The exact approved dialogue is preserved for %s." % character)
		_expect(not str(definition.get("dialogue", "")).is_empty() and not str(definition.get("accept_label", "")).is_empty() and not str(definition.get("decline_label", "")).is_empty(), "Offer %s includes dialogue and both choices." % character)
	var dot := _definition("dot")
	_expect(int(dot.get("heat_reduction", -1)) == 8, "Dot reduces Heat by the approved eight points.")
	_expect((dot.get("hosts", {}) as Dictionary).size() == 3, "Dot references one canonical offer across three venues.")
	var coffee := _definition("rafi")
	_expect(int(coffee.get("cash_cost", -1)) == 3 and int(coffee.get("minutes", -1)) == 10, "Coffee costs exactly $3 and ten minutes.")
	var glasses := _definition("lena")
	_expect(str(glasses.get("required_item_id", "")) == "cheap_sunglasses" and int(glasses.get("cash_reward", -1)) == 9, "Lena buys only the approved Cheap Sunglasses for $9.")
	_expect(not str(glasses.get("item_summary", "")).is_empty(), "The glasses preview discloses lost benefits.")


func _environment(archetype_id: String, minute: int) -> Dictionary:
	var rows: Array = []
	for value in CharacterOfferModelScript.definitions():
		var definition: Dictionary = value
		var host_id := str((definition.get("hosts", {}) as Dictionary).get(archetype_id, ""))
		if host_id.is_empty():
			continue
		rows.append({
			"instance_object_id": host_id,
			"presentation_object_id": host_id,
			"object_id": host_id,
			"family": "fixed",
			"object_type": "character",
			"active": true,
			"physical": true,
			"action_ids": [],
		})
	return {
		"id": "offer_fixture:%s" % archetype_id,
		"archetype_id": archetype_id,
		"world_node_id": archetype_id,
		"display_name": "Offer fixture %s" % archetype_id,
		"kind": str(library.environment_archetype(archetype_id).get("kind", "shop")),
		"turns": 4,
		"entered_game_clock_minutes": minute,
		"object_manifest": {"rows": rows},
	}


func _new_run(character: String, seed: String, minute: int = 1380, archetype_override: String = "") -> RunState:
	var run: RunState = RunStateScript.new()
	run.start_new(seed)
	run.game_clock_minutes = minute
	var hosts: Dictionary = _definition(character).get("hosts", {})
	var archetype_id := archetype_override if not archetype_override.is_empty() else str(hosts.keys()[0])
	run.current_environment = _environment(archetype_id, minute)
	run.event_cadence_begin_visit(run.current_environment)
	run.bankroll = 100
	run.drunk_level = 12
	run.change_pending_drunk_absorption(16)
	run.suspicion["level"] = 20
	run.inventory = ["cheap_sunglasses", "bag"]
	run.initialize_home_from_profile(library.environment_archetype("apartment"), "actual_home", {"tenure": {"type": "rent", "first_due_in_days": 7, "grace_days": 3}})
	return run


func _view(run: RunState, character: String) -> Dictionary:
	return CharacterOfferModelScript.view(run, library, str(OFFER_IDS[character]))


func _record(run: RunState, character: String) -> Dictionary:
	return (run.narrative_flags.get(STATE_KEY, {}) as Dictionary).get(character, {})


func _winner(character: String, minute: int = 1380, archetype_id: String = "") -> RunState:
	for index in range(128):
		var run := _new_run(character, "OPTIONAL-OFFER-%03d" % index, minute, archetype_id)
		if not _view(run, character).is_empty():
			return run
	_expect(false, "A bounded deterministic seed probe finds a winning %s offer." % character)
	return null


func _resolve(run: RunState, character: String, accept: bool) -> Dictionary:
	var offer := _view(run, character)
	if offer.is_empty():
		_expect(false, "%s has a visible offer before its response." % character)
		return {"ok": false}
	return CharacterOfferModelScript.resolve(run, library, str(OFFER_IDS[character]), offer.get("token", {}), accept)


func _check_rolls_and_save_persistence() -> void:
	var saw_win := false
	var saw_miss := false
	for index in range(24):
		var seed := "OFFER-ROLL-PERSIST-%03d" % index
		var first := _new_run("rafi", seed)
		var twin := _new_run("rafi", seed)
		# Eligibility must not decide whether the day's random roll is remembered.
		first.drunk_level = 0
		first.pending_drunk_absorption = []
		first.bankroll = 0
		var rng_before := first.rng_state
		CharacterOfferModelScript.synchronize(first)
		CharacterOfferModelScript.synchronize(twin)
		var remembered := _record(first, "rafi").duplicate(true)
		_expect(not remembered.is_empty(), "An ineligible present Rafi still records his deterministic roll (%s)." % seed)
		_expect(remembered.get("roll") == _record(twin, "rafi").get("roll"), "Eligibility does not change Rafi's deterministic roll (%s)." % seed)
		_expect(first.rng_state == rng_before, "Offer projection does not consume the gameplay RNG (%s)." % seed)
		for _repeat_index in range(3):
			_view(first, "rafi")
		_expect(_record(first, "rafi") == remembered, "Repeated review does not reroll (%s)." % seed)
		var serialized := JSON.stringify(RunSaveCodecScript.encode(first.to_save_snapshot()))
		var parsed: Variant = JSON.parse_string(serialized)
		var restored: RunState = RunStateScript.new()
		restored.from_dict(RunSaveCodecScript.decode(parsed as Dictionary))
		CharacterOfferModelScript.synchronize(restored)
		var json_remembered: Dictionary = JSON.parse_string(JSON.stringify(remembered))
		_expect(_record(restored, "rafi") == json_remembered, "JSON codec/save-load preserves even an ineligible or missed roll (%s)." % seed)
		saw_win = saw_win or str(remembered.get("status", "")) == "available"
		saw_miss = saw_miss or str(remembered.get("status", "")) == "missed"
	_expect(saw_win and saw_miss, "The deterministic probe exercises both winning and missed rolls.")


func _check_decline_and_departure() -> void:
	var run := _winner("marco")
	if run == null:
		return
	var offer := _view(run, "marco")
	var before_cash := run.bankroll
	var before_clock := run.game_clock_minutes
	var declined := CharacterOfferModelScript.resolve(run, library, str(OFFER_IDS.marco), offer.token, false)
	_expect(bool(declined.get("ok", false)), "Declining Marco resolves his cycle.")
	_expect(run.bankroll == before_cash and run.game_clock_minutes == before_clock, "Declining has no cash or time penalty.")
	_expect(_view(run, "marco").is_empty(), "A declined offer cannot be reopened during the same cycle.")
	var repeated := CharacterOfferModelScript.resolve(run, library, str(OFFER_IDS.marco), offer.token, true)
	_expect(not bool(repeated.get("ok", false)) and run.bankroll == before_cash, "A stale response cannot claim a declined offer.")
	var departure := _winner("marco")
	if departure == null:
		return
	var original_environment := departure.current_environment.duplicate(true)
	var original_roll: Variant = _record(departure, "marco").get("roll")
	var changed: Dictionary = departure.set_environment(_environment("bar", departure.game_clock_minutes))
	_expect(bool(changed.get("ok", false)), "Canonical environment installation can leave an unclaimed offer.")
	departure.set_environment(original_environment)
	CharacterOfferModelScript.synchronize(departure)
	_expect(_view(departure, "marco").is_empty() and _record(departure, "marco").get("roll") == original_roll, "Departure and reentry expire the offer without another roll.")


func _check_operating_cycles() -> void:
	var overnight := _winner("rafi", 23 * 60)
	if overnight != null:
		var before := _record(overnight, "rafi").duplicate(true)
		var before_midnight := overnight.advance_game_clock_minutes(3 * 60)
		_expect(bool(before_midnight.get("ok", false)) and overnight.game_clock_minutes == 26 * 60, "Canonical bar time can cross midnight before checking its operating cycle.")
		CharacterOfferModelScript.synchronize(overnight)
		_expect(_record(overnight, "rafi").get("cycle_id") == before.get("cycle_id") and _record(overnight, "rafi").get("roll") == before.get("roll"), "Rafi's after-midnight hours share the preceding opening's roll.")
		var to_close := overnight.advance_game_clock_minutes(60)
		_expect(bool(to_close.get("ok", false)) and overnight.game_clock_minutes == 27 * 60, "Canonical bar time reaches the real 03:00 close.")
		_expect(_view(overnight, "rafi").is_empty(), "Rafi's offer expires at the real 03:00 close.")
	var all_day := _winner("marco", 1430)
	if all_day != null:
		var before_cycle := str(_record(all_day, "marco").get("cycle_id", ""))
		all_day.advance_game_clock_minutes(11)
		CharacterOfferModelScript.synchronize(all_day)
		_expect(str(_record(all_day, "marco").get("cycle_id", "")) != before_cycle, "A 24-hour venue begins one new offer cycle at game-day rollover.")
	var dot := _winner("dot", 12 * 60, "bar")
	if dot != null:
		var before_dot := _record(dot, "dot").duplicate(true)
		dot.advance_game_clock_minutes(2 * 60)
		CharacterOfferModelScript.synchronize(dot)
		_expect(_record(dot, "dot").get("cycle_id") == before_dot.get("cycle_id") and _record(dot, "dot").get("roll") == before_dot.get("roll"), "Dot's shared cycle does not reset when the lounge opens at 13:00.")
	var last_coffee := _winner("rafi", 1440 + 170)
	if last_coffee != null:
		_expect(not _view(last_coffee, "rafi").is_empty(), "Exactly ten minutes before close permits coffee.")
		last_coffee.advance_game_clock_minutes(1)
		_expect(_view(last_coffee, "rafi").is_empty(), "Nine minutes before close blocks coffee.")
	var last_company := _winner("dot", 1440 + 160, "bar")
	if last_company != null:
		_expect(not _view(last_company, "dot").is_empty(), "Exactly twenty minutes before close permits Dot's offer.")
		last_company.advance_game_clock_minutes(1)
		_expect(_view(last_company, "dot").is_empty(), "Nineteen minutes before close blocks Dot's offer.")


func _check_marco_transition() -> void:
	var run := _winner("marco")
	if run == null:
		return
	var offer := _view(run, "marco")
	var cash := run.bankroll
	var clock := run.game_clock_minutes
	var turns := int(run.current_environment.get("turns", 0))
	var action_index := int(run.event_cadence.get("action_index", 0))
	var frozen := run.to_save_snapshot()
	var result := _resolve(run, "marco", true)
	_expect(bool(result.get("ok", false)) and run.bankroll == cash + 6 and run.game_clock_minutes == clock + 20, "Marco advances twenty minutes and pays exactly $6.")
	_expect(str(run.current_environment.get("archetype_id", "")) == "motel", "Helping Marco stays at the motel.")
	_expect(int(run.current_environment.get("turns", 0)) == turns and int(run.event_cadence.get("action_index", 0)) == action_index, "A timed offer invents no action turns or default action minutes.")
	var frozen_flags: Dictionary = frozen.get("narrative_flags", {})
	var frozen_cycles: Dictionary = frozen_flags.get(STATE_KEY, {})
	_expect(str((frozen_cycles.get("marco", {}) as Dictionary).get("status", "")) == "available" and str(_record(run, "marco").get("status", "")) == "accepted", "Publishing a claim cannot mutate an already captured in-flight save snapshot.")
	var retry := CharacterOfferModelScript.resolve(run, library, str(OFFER_IDS.marco), offer.token, true)
	_expect(not bool(retry.get("ok", false)) and run.bankroll == cash + 6 and run.game_clock_minutes == clock + 20, "Marco's accepted response applies exactly once.")
	var restored: RunState = RunStateScript.new()
	restored.from_dict(RunSaveCodecScript.decode(RunSaveCodecScript.encode(run.to_save_snapshot())))
	_expect(_view(restored, "marco").is_empty(), "A claimed reward remains claimed after save-load.")


func _check_coffee_transition() -> void:
	var run := _winner("rafi")
	if run == null:
		return
	run.bankroll = 3
	var clock := run.game_clock_minutes
	var inventory := run.inventory.duplicate(true)
	var baseline_luck := run.baseline_luck
	var drunk_before := run.drunk_level
	var pending_before := run.pending_drunk_absorption_amount()
	var result := _resolve(run, "rafi", true)
	_expect(bool(result.get("ok", false)) and run.bankroll == 0 and run.game_clock_minutes == clock + 10, "Coffee accepts exact cash and applies only its $3/ten-minute cost.")
	_expect(run.drunk_level == maxi(0, drunk_before - 10) and run.pending_drunk_absorption_amount() == maxi(0, pending_before - 10), "Coffee reduces both Drunk and queued alcohol by up to ten, even when some absorption remains.")
	_expect(run.inventory == inventory and run.baseline_luck == baseline_luck, "Coffee creates no resale item or luck bonus.")
	_expect(str(run.current_environment.get("archetype_id", "")) == "bar", "Coffee stays in the bar.")
	var low := _winner("rafi")
	if low != null:
		low.drunk_level = 3
		low.pending_drunk_absorption = []
		low.change_pending_drunk_absorption(4)
		_resolve(low, "rafi", true)
		_expect(low.drunk_level == 0 and low.pending_drunk_absorption_amount() == 0, "Coffee clamps both alcohol reductions at zero.")


func _check_lena_transition() -> void:
	var run := _winner("lena")
	if run == null:
		return
	var reserved := {"id": "cheap_sunglasses", "reserved": true}
	run.inventory = [reserved, "cheap_sunglasses", "bag"]
	var cash := run.bankroll
	var clock := run.game_clock_minutes
	var result := _resolve(run, "lena", true)
	_expect(bool(result.get("ok", false)) and run.bankroll == cash + 9 and run.game_clock_minutes == clock + 5, "Lena pays $9 and advances five minutes.")
	_expect(run.inventory == [reserved, "bag"], "Lena removes exactly one available carried pair while retaining reserved glasses and other items.")
	var protected := _winner("lena")
	if protected == null:
		return
	protected.inventory = [reserved, "bag"]
	_expect(_view(protected, "lena").is_empty(), "Reserved carried glasses cannot be sold to Lena.")
	protected.inventory = [{"id": "cheap_sunglasses", "collateral": true}]
	protected.debt = [{"id": "offer_test_pawn", "status": "active", "collateral_item_id": "cheap_sunglasses"}]
	_expect(_view(protected, "lena").is_empty(), "Collateral glasses cannot be sold to Lena.")
	protected.inventory = ["cheap_sunglasses"]
	_expect(not _view(protected, "lena").is_empty(), "A separately reacquired available pair remains sellable while another pair is pawn collateral.")
	protected.inventory = ["bag"]
	protected.current_environment["home_containers"] = [{"id": "closet", "items": ["cheap_sunglasses"]}]
	_expect(_view(protected, "lena").is_empty(), "Home storage does not satisfy Lena's carried-item condition.")


func _check_dot_transition() -> void:
	var run := _winner("dot", 1380, "bar")
	if run == null:
		return
	run.drunk_level = 80
	var clock := run.game_clock_minutes
	var cash := run.bankroll
	var luck := run.baseline_luck
	var result := _resolve(run, "dot", true)
	_expect(bool(result.get("ok", false)) and run.suspicion_level() == 12, "Dot reduces Heat by eight even at high Drunk.")
	_expect(run.game_clock_minutes == clock + 20 and run.bankroll == cash and run.baseline_luck == luck, "Dot is free, lasts twenty minutes, and adds no odds modifier.")
	run.set_environment(_environment("jazz_club", run.game_clock_minutes))
	_expect(_view(run, "dot").is_empty(), "Dot cannot pay another reward after moving to the jazz club in the same shared cycle.")
	run.set_environment(_environment("kitty_cat_lounge", run.game_clock_minutes))
	_expect(_view(run, "dot").is_empty(), "Dot cannot pay another reward after moving to the lounge in the same shared cycle.")
	var low := _winner("dot", 1380, "bar")
	if low != null:
		low.suspicion["level"] = 2
		_resolve(low, "dot", true)
		_expect(low.suspicion_level() == 0, "Dot clamps the eight-point reduction at zero.")


func _check_stale_selection() -> void:
	var run := _winner("rafi")
	if run == null:
		return
	var offer := _view(run, "rafi")
	run.bankroll = 2
	var cash := run.bankroll
	var clock := run.game_clock_minutes
	var rejected := CharacterOfferModelScript.resolve(run, library, str(OFFER_IDS.rafi), offer.token, true)
	_expect(not bool(rejected.get("ok", false)) and run.bankroll == cash and run.game_clock_minutes == clock, "A stale coffee quote revalidates affordability without charging.")
	run.bankroll = 100
	var refreshed := _view(run, "rafi")
	run.advance_game_clock_minutes(1)
	var stale_clock := CharacterOfferModelScript.resolve(run, library, str(OFFER_IDS.rafi), refreshed.get("token", {}), true)
	_expect(not bool(stale_clock.get("ok", false)) and run.bankroll == 100, "A stale time selection requires a current preview.")
	var shades := _winner("lena")
	if shades != null:
		var sale := _view(shades, "lena")
		shades.inventory = ["bag"]
		var sale_cash := shades.bankroll
		var invalid_sale := CharacterOfferModelScript.resolve(shades, library, str(OFFER_IDS.lena), sale.token, true)
		_expect(not bool(invalid_sale.get("ok", false)) and shades.bankroll == sale_cash, "A stale Lena response cannot sell a missing or different item.")


func _check_clock_consequences() -> void:
	var run := _winner("marco", 1430)
	if run == null:
		return
	run.initialize_home_from_profile(library.environment_archetype("motel_room"), "expiry_home", {"tenure": {"type": "stay", "prepaid_days": 1}})
	# A legacy/unmounted delivery is sufficient to exercise the same canonical
	# deadline and exactly-once world consequences as an offer's real clock call.
	run.active_delivery_run = DeliveryRunModelScript.begin({
		"run_id": "optional_offer_deadline",
		"mode": "package",
		"start_node_id": "motel",
		"targets": [{"node_id": "delivery_destination", "label": "Destination"}],
		"deadline_kind": "clock",
		"started_game_clock_minutes": run.game_clock_minutes,
		"deadline_minutes": 5,
		"consumer_payload": {"failure": {"flags": {"offer_deadline_applied": true}}},
	}, 0)
	_expect(not run.active_delivery_run.is_empty(), "Clock-consequence fixture has an active delivery.")
	var result := _resolve(run, "marco", true)
	_expect(bool(result.get("ok", false)) and run.game_day() == 2, "Marco's accepted time crosses the real game-day boundary.")
	_expect(not run.home_is_active(), "Offer time applies ordinary prepaid-home expiry at midnight.")
	_expect(str(run.active_delivery_run.get("status", "")) == "resolved" and bool(run.narrative_flags.get("offer_deadline_applied", false)), "Offer time applies delivery deadlines and authored consequences.")
	var interest := _winner("marco", 1440 + 170)
	if interest != null:
		interest._set_grand_casino_atm_debt(100)
		interest.grand_casino_atm_interest_boundary_index = -1
		_resolve(interest, "marco", true)
		_expect(interest.grand_casino_atm_debt() == 105, "Offer time applies the normal 03:00 ATM interest boundary once.")


func _iris_fixture(run: RunState, prepaid_days: int = 4, distance_blocks: int = 4) -> void:
	var home_archetype := library.environment_archetype("motel_room")
	run.initialize_home_from_profile(home_archetype, "motel_room", {"tenure": {"type": "stay", "prepaid_days": prepaid_days}})
	run.home_state["display_name"] = "Harbor Test Room"
	var home_environment := EnvironmentInstanceScript.from_archetype(home_archetype, 0, run.create_rng("offer_home_fixture"), library).to_dict()
	home_environment["world_node_id"] = "motel_room"
	home_environment["home_lost"] = false
	run.world_map = WorldMapScript.normalize({
		"version": 3,
		"start_node_id": "motel_room",
		"current_node_id": "kitty_cat_lounge",
		"visited_path": ["motel_room", "kitty_cat_lounge"],
		"nodes": [
			{"id": "kitty_cat_lounge", "archetype_id": "kitty_cat_lounge", "kind": "casino", "state": "visited", "seen": true},
			{"id": "motel_room", "archetype_id": "motel_room", "kind": "home", "state": "visited", "seen": true, "environment": home_environment},
			{"id": "apartment", "archetype_id": "apartment", "kind": "home", "state": "visited", "seen": true},
		],
		"edges": [
			{"a": "kitty_cat_lounge", "b": "motel_room", "distance_blocks": distance_blocks, "base_cost": 8, "cost": 8},
			{"a": "kitty_cat_lounge", "b": "apartment", "distance_blocks": 1, "base_cost": 3, "cost": 3},
		],
	})
	run.current_environment["world_map_travel"] = true
	run.current_environment["travel_hooks"] = ["motel_room", "apartment"]
	run.current_environment["next_archetypes"] = ["motel_room", "apartment"]
	run.drunk_level = 0
	run.pending_drunk_absorption = []
	run.suspicion["level"] = 0


func _check_rejected_consequences() -> void:
	var dot := _winner("dot", 1380, "bar")
	if dot != null:
		var rejected_heat: RunState = RejectingHeatRun.new()
		rejected_heat.from_dict(dot.to_dict())
		var heat_offer := _view(rejected_heat, "dot")
		var before_heat := rejected_heat.to_dict()
		var heat_result := CharacterOfferModelScript.resolve(rejected_heat, library, str(OFFER_IDS.dot), heat_offer.get("token", {}), true)
		_expect(not bool(heat_result.get("ok", false)), "A rejected canonical Heat fact rejects Dot's offer.")
		_expect(rejected_heat.to_dict() == before_heat, "Heat ingress failure rolls back time, Heat, claim and all other run state.")
	var marco := _winner("marco")
	if marco != null:
		var rejected_flush: RunState = RejectingFlushRun.new()
		rejected_flush.from_dict(marco.to_dict())
		var flush_offer := _view(rejected_flush, "marco")
		var before_flush := rejected_flush.to_dict()
		var flush_result := CharacterOfferModelScript.resolve(rejected_flush, library, str(OFFER_IDS.marco), flush_offer.get("token", {}), true)
		_expect(not bool(flush_result.get("ok", false)), "A rejected canonical fact flush rejects the offer transaction.")
		_expect(rejected_flush.to_dict() == before_flush, "Fact-flush failure publishes no time, cash reward, claim or story consequence.")


func _iris_host(run: RunState, reject_install: bool = false) -> IrisHost:
	var host := IrisHost.new()
	host.library = library
	host.run_state = run
	host.generator = RejectingTravelGenerator.new(library) if reject_install else RunGeneratorScript.new(library)
	for field in host.RUN_UI_SCRIPT_PATHS:
		host.set(str(field), load(str(host.RUN_UI_SCRIPT_PATHS[field])))
	host.current_screen = host.SCREEN_ENVIRONMENT
	return host


func _iris_popup(host: IrisHost, offer: Dictionary, preview: Dictionary) -> void:
	host.pending_event_choice_popup_snapshot = {
		"popup_type": "character_offer",
		"offer_id": str(OFFER_IDS.iris),
		"token": offer.get("token", {}),
		"route_preview": preview,
	}


func _check_iris_preview_and_transition() -> void:
	var run := _winner("iris", 22 * 60)
	if run == null:
		return
	_iris_fixture(run)
	var host := _iris_host(run)
	var offer := _view(run, "iris")
	var clock := run.game_clock_minutes
	var home_before := run.home_state.duplicate(true)
	var preview: Dictionary = host._character_offer_route_preview(offer)
	_expect(not preview.is_empty(), "Iris can preview a real, active motel-room route.")
	if preview.is_empty():
		host.free()
		return
	_expect(str(preview.get("home_node_id", "")) == "motel_room" and str(preview.get("home_name", "")) == "Harbor Test Room", "Iris names the player's actual home instead of the decoy apartment.")
	_expect(int(preview.get("wait_minutes", -1)) == 420 and int(preview.get("departure_game_clock_minutes", -1)) == 1740, "A 22:00 ride waits exactly until the relevant 05:00 shift end.")
	var route: Dictionary = preview.get("route", {})
	_expect(int(route.get("cost", -1)) == 0 and int(preview.get("travel_minutes", 0)) == host._travel_clock_minutes_for_route(route), "Iris waives fare and preserves normal route duration.")
	_expect(int(preview.get("arrival_game_clock_minutes", -1)) == 1740 + int(preview.get("travel_minutes", 0)), "Iris discloses departure, wait, travel and arrival consistently.")
	_expect(str(preview.get("summary", "")).contains("Harbor Test Room") and str(preview.get("summary", "")).contains("Wait:") and str(preview.get("summary", "")).contains("Depart:") and str(preview.get("summary", "")).contains("Arrive:"), "Iris's review contains actual home, fare and complete timing.")
	_expect(run.game_clock_minutes == clock and run.home_state == home_before, "Iris's forecast does not advance or mutate the live home.")
	var cash := run.bankroll
	_iris_popup(host, offer, preview)
	var accepted: Dictionary = host._resolve_character_offer_response(str(OFFER_IDS.iris), offer.token, true)
	_expect(bool(accepted.get("ok", false)), "The production Iris response can complete its wait-and-travel transition.")
	_expect(run.current_world_node_id() == "motel_room" and run.is_current_home_environment(), "The production Iris response arrives at the same actual active home.")
	_expect(run.game_clock_minutes == int(preview.get("arrival_game_clock_minutes", -1)) and run.bankroll == cash, "Iris charges no fare and applies exactly the previewed wait plus travel time.")
	_expect(not host.saved_home_ids.is_empty() and str(host.saved_home_ids[0]) == "motel_room", "Iris saves only after the safe home arrival is committed.")
	var accepted_cash := run.bankroll
	var accepted_clock := run.game_clock_minutes
	var repeated: Dictionary = host._resolve_character_offer_response(str(OFFER_IDS.iris), offer.token, true)
	_expect(not bool(repeated.get("ok", false)) and run.bankroll == accepted_cash and run.game_clock_minutes == accepted_clock, "An old Iris callback cannot apply the ride twice.")
	host.free()

	var expired := _winner("iris", 22 * 60)
	if expired != null:
		_iris_fixture(expired, 1)
		var expiry_host := _iris_host(expired)
		_expect(expiry_host._character_offer_route_preview(_view(expired, "iris")).is_empty(), "Iris is unavailable when the actual home expires during the wait.")
		_expect(expired.home_is_active() and expired.game_clock_minutes == 1320, "An unsafe Iris forecast leaves the live home and clock intact.")
		expiry_host.free()
	var arrival_expiry := _winner("iris", 22 * 60)
	if arrival_expiry != null:
		_iris_fixture(arrival_expiry, 2, 200)
		var arrival_host := _iris_host(arrival_expiry)
		_expect(arrival_host._character_offer_route_preview(_view(arrival_expiry, "iris")).is_empty(), "Iris is unavailable when home lasts through departure but expires before a long route arrives.")
		arrival_host.free()
	var missing := _winner("iris", 22 * 60)
	if missing != null:
		_iris_fixture(missing)
		missing.world_map["edges"] = [{"a": "kitty_cat_lounge", "b": "apartment", "distance_blocks": 1}]
		var missing_host := _iris_host(missing)
		_expect(missing_host._character_offer_route_preview(_view(missing, "iris")).is_empty(), "Iris never substitutes the reachable decoy apartment for an unreachable actual home.")
		missing_host.free()
	var rejected := _winner("iris", 22 * 60)
	if rejected != null:
		_iris_fixture(rejected)
		var rejection_host := _iris_host(rejected, true)
		var rejection_offer := _view(rejected, "iris")
		var rejection_preview: Dictionary = rejection_host._character_offer_route_preview(rejection_offer)
		_iris_popup(rejection_host, rejection_offer, rejection_preview)
		var before_clock := rejected.game_clock_minutes
		var before_cash := rejected.bankroll
		var before_cycle := _record(rejected, "iris").duplicate(true)
		var rejected_result: Dictionary = rejection_host._resolve_character_offer_response(str(OFFER_IDS.iris), rejection_offer.token, true)
		_expect(not bool(rejected_result.get("ok", false)), "An injected destination-install failure rejects the Iris transaction.")
		_expect(rejected.game_clock_minutes == before_clock and rejected.bankroll == before_cash and _record(rejected, "iris") == before_cycle, "A rejected Iris destination rolls back wait, claim and money exactly.")
		_expect(rejection_host.saved_home_ids.is_empty(), "A rejected Iris arrival is never autosaved.")
		rejection_host.free()
