extends SceneTree

# Focused native contract for June's watch sale and Sable's repair. It creates
# no rendered scene and uses the production offer, clock, item and save APIs.
# godot --headless --path . --script res://scripts/tests/character_offers_batch_two_check.gd

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const OfferModel := preload("res://scripts/core/character_offer_model.gd")
const RunSaveCodecScript := preload("res://scripts/core/run_save_codec.gd")
const DeliveryRunModelScript := preload("res://scripts/core/delivery_run_model.gd")
const STATE_KEY := "character_offer_cycles"


class RejectingClockRun extends "res://scripts/core/run_state.gd":
	func advance_game_clock_minutes(_amount: int) -> Dictionary:
		return {"ok": false, "applied": false, "errors": ["Batch-two contract rejected clock advancement."]}


class RejectingFlushRun extends "res://scripts/core/run_state.gd":
	func scenario_flush_facts(_boundary_serial: int = -1) -> Dictionary:
		return {"ok": false, "errors": ["Batch-two contract rejected fact flush."]}


var library: ContentLibrary
var failures: Array = []
var assertions := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	library = ContentLibraryScript.new()
	var loaded: Dictionary = library.load(false)
	_expect(not (loaded.get("environment_archetypes", []) as Array).is_empty(), "Production content loads.")
	_check_definitions()
	if failures.is_empty():
		_check_roll_and_save()
		_check_june()
		_check_sable()
		_check_shared_cycle_and_expiry()
		_check_stale_selection()
		_check_clock_consequences()
		_check_rejected_transactions()
	for failure in failures:
		printerr("CHARACTER OFFERS BATCH TWO: %s" % str(failure))
	print("CHARACTER OFFERS BATCH TWO CHECK assertions=%d failures=%d ok=%s" % [assertions, failures.size(), str(failures.is_empty())])
	quit(0 if failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _definition(character: String) -> Dictionary:
	for value in OfferModel.definitions():
		var offer: Dictionary = value
		if str(offer.get("character_id", "")) == character:
			return offer
	return {}


func _check_definitions() -> void:
	var june := _definition("june")
	var sable := _definition("sable")
	_expect(not june.is_empty() and not sable.is_empty(), "Both approved canonical characters have offer attributes.")
	_expect(_definition("ox").is_empty(), "The unapproved Ox offer is absent.")
	_expect(int(june.get("chance_percent", -1)) == 25 and int(june.get("cash_cost", -1)) == 5 and int(june.get("minutes", -1)) == 15, "June preserves the approved 25%, $5 and fifteen-minute terms.")
	_expect(june.get("hosts", {}) == {"motel": "motel:june"}, "June uses her existing motel placement.")
	_expect(str(june.get("inventory_add_item_id", "")) == "pocket_watch" and str(june.get("excluded_carried_item_id", "")) == "pocket_watch", "June grants one Pocket Watch and excludes an already carried watch.")
	_expect(int(sable.get("chance_percent", -1)) == 20 and int(sable.get("cash_cost", -1)) == 0 and int(sable.get("minutes", -1)) == 45, "Sable preserves the approved 20%, free and forty-five-minute terms.")
	_expect(int(sable.get("minimum_minutes_before_close", -1)) == 45, "Sable requires enough open time to complete the forty-five-minute repair.")
	_expect(sable.get("hosts", {}) == {"small_underground_casino": "punchline:casino_dealer", "delta_queen": "delta_queen:right_table_dealer"}, "One canonical Sable offer uses both existing dealer placements.")
	_expect(str(sable.get("required_item_id", "")) == "broken_cufflinks" and str(sable.get("inventory_add_item_id", "")) == "coolers_cufflinks" and str(sable.get("excluded_carried_item_id", "")) == "coolers_cufflinks", "Sable exchanges one Broken Cufflinks for Cooler's Cufflinks and prevents a duplicate target.")
	for offer in [june, sable]:
		_expect(not str(offer.get("item_gain_summary", "")).is_empty() and not str(offer.get("dialogue", "")).is_empty(), "Both offers disclose item effects and authored dialogue.")
		_expect(not str(offer.get("accept_label", "")).is_empty() and not str(offer.get("decline_label", "")).is_empty(), "Both offers provide explicit accept and decline choices.")


func _environment(archetype: String, minute: int) -> Dictionary:
	var rows: Array = []
	for value in OfferModel.definitions():
		var offer: Dictionary = value
		var host_id := str((offer.get("hosts", {}) as Dictionary).get(archetype, ""))
		if not host_id.is_empty():
			rows.append({"instance_object_id": host_id, "presentation_object_id": host_id, "object_id": host_id, "family": "fixed", "object_type": "character", "active": true, "physical": true, "action_ids": []})
	return {
		"id": "batch_two_fixture:%s" % archetype,
		"archetype_id": archetype, "world_node_id": archetype,
		"display_name": "Offer fixture %s" % archetype, "kind": "shop",
		"turns": 4, "entered_game_clock_minutes": minute,
		"visual_context": {}, "travel_lock_remaining": 0, "game_states": {},
		"object_manifest": {"rows": rows},
	}


func _fresh(character: String, seed: String, minute: int = 720, venue: String = "") -> RunState:
	var run: RunState = RunStateScript.new()
	run.start_new(seed)
	run.game_clock_minutes = minute
	var archetype := venue
	if archetype.is_empty():
		# Delta Queen's base map contains Sable. A minimal Punchline base room is
		# the comedy-club layer, so a canonical rebuild correctly removes her.
		archetype = "motel" if character == "june" else "delta_queen"
	run.current_environment = _environment(archetype, minute)
	run.event_cadence_begin_visit(run.current_environment)
	run.inventory = ["bag"] if character == "june" else ["broken_cufflinks", "bag"]
	return run


func _view(run: RunState, character: String) -> Dictionary:
	return OfferModel.view(run, library, str(_definition(character).get("id", "")))


func _record(run: RunState, character: String) -> Dictionary:
	return (run.narrative_flags.get(STATE_KEY, {}) as Dictionary).get(character, {})


func _winner(character: String, minute: int = 720, venue: String = "") -> RunState:
	for index in range(64):
		var run := _fresh(character, "OFFER-BATCH-TWO-%02d" % index, minute, venue)
		if not _view(run, character).is_empty():
			return run
	_expect(false, "Bounded deterministic seeds produce a winning %s offer." % character)
	return null


func _resolve(run: RunState, character: String, accept: bool = true) -> Dictionary:
	var offer := _view(run, character)
	_expect(not offer.is_empty(), "%s has an eligible offer before the response." % character)
	if offer.is_empty():
		return {"ok": false}
	return OfferModel.resolve(run, library, str(offer.get("id", "")), offer.get("token", {}), accept)


func _item_count(run: RunState, item_id: String) -> int:
	var count := 0
	for value in run.inventory:
		var id := str(value.get("id", value.get("item_id", ""))) if typeof(value) == TYPE_DICTIONARY else str(value)
		if id == item_id:
			count += 1
	return count


func _restore(run: RunState) -> RunState:
	var encoded := RunSaveCodecScript.encode(run.to_save_snapshot())
	var wire: Variant = JSON.parse_string(JSON.stringify(encoded))
	var restored: RunState = RunStateScript.new()
	restored.from_dict(RunSaveCodecScript.decode(wire as Dictionary))
	return restored


func _same_saved_record(expected: Dictionary, actual: Dictionary) -> bool:
	# JSON restores numeric scalars as floats. Compare the exact integral roll
	# value while retaining strict comparison of every other field and key.
	var expected_roll: Variant = expected.get("roll")
	var actual_roll: Variant = actual.get("roll")
	if typeof(expected_roll) not in [TYPE_INT, TYPE_FLOAT] or typeof(actual_roll) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	if not is_finite(float(actual_roll)) or float(actual_roll) != float(expected_roll) or float(actual_roll) != floor(float(actual_roll)):
		return false
	var normalized := actual.duplicate(true)
	normalized["roll"] = int(actual_roll)
	return normalized == expected


func _check_roll_and_save() -> void:
	for character in ["june", "sable"]:
		var saw_miss := false
		var saw_win := false
		for index in range(12):
			var seed := "BATCH-TWO-PERSIST-%02d" % index
			var run := _fresh(character, seed)
			var twin := _fresh(character, seed)
			run.bankroll = 0 if character == "june" else 100
			run.inventory = []
			var rng := run.rng_state
			OfferModel.synchronize(run)
			OfferModel.synchronize(twin)
			var remembered := _record(run, character).duplicate(true)
			_expect(not remembered.is_empty() and remembered.get("roll") == _record(twin, character).get("roll"), "Ineligibility still saves %s's same deterministic roll." % character)
			_view(run, character)
			_view(run, character)
			_expect(_record(run, character) == remembered and run.rng_state == rng, "Repeated %s review neither rerolls nor consumes game RNG." % character)
			var restored := _restore(run)
			OfferModel.synchronize(restored)
			_expect(_same_saved_record(remembered, _record(restored, character)), "JSON save-load preserves %s's unclaimed or missed roll." % character)
			saw_win = saw_win or str(remembered.get("status", "")) == "available"
			saw_miss = saw_miss or str(remembered.get("status", "")) == "missed"
		_expect(saw_win and saw_miss, "The bounded %s persistence sample covers wins and misses." % character)


func _check_june() -> void:
	var run := _winner("june")
	if run == null:
		return
	run.bankroll = 5
	var offer := _view(run, "june")
	_expect(str(offer.get("summary", "")).contains("$5") and str(offer.get("summary", "")).contains("15 minutes") and str(offer.get("summary", "")).contains("Pocket Watch"), "June's review shows the full cash, time and item terms before acceptance.")
	var frozen := run.to_save_snapshot()
	var clock := run.game_clock_minutes
	var turns := int(run.current_environment.get("turns", 0))
	var actions := int(run.event_cadence.get("action_index", 0))
	var result := _resolve(run, "june")
	_expect(bool(result.get("ok", false)) and run.bankroll == 0 and run.game_clock_minutes == clock + 15, "June accepts exactly $5 and advances exactly fifteen minutes.")
	_expect(_item_count(run, "pocket_watch") == 1 and _item_count(run, "bag") == 1 and str(run.current_environment.get("archetype_id", "")) == "motel", "June grants one Pocket Watch, keeps other items and stays at the motel.")
	_expect(run.item_effect_total("exact_clock_minutes") == 1, "June's canonical item grant activates the Pocket Watch's normal exact-clock effect.")
	_expect(int(run.current_environment.get("turns", 0)) == turns and int(run.event_cadence.get("action_index", 0)) == actions, "June invents no action turns or extra default time.")
	var frozen_cycles: Dictionary = (frozen.get("narrative_flags", {}) as Dictionary).get(STATE_KEY, {})
	_expect(str((frozen_cycles.get("june", {}) as Dictionary).get("status", "")) == "available", "June's claim cannot mutate an in-flight save snapshot.")
	var retry := OfferModel.resolve(run, library, str(offer.get("id", "")), offer.get("token", {}), true)
	_expect(not bool(retry.get("ok", false)) and _item_count(run, "pocket_watch") == 1 and run.game_clock_minutes == clock + 15, "June's stale callback cannot grant or charge twice.")
	var restored := _restore(run)
	_expect(_view(restored, "june").is_empty() and _item_count(restored, "pocket_watch") == 1 and str(_record(restored, "june").get("status", "")) == "accepted", "June's grant and claim survive save-load.")
	var owns := _winner("june")
	if owns == null:
		return
	for entry in ["pocket_watch", {"id": "pocket_watch"}, {"id": "pocket_watch", "reserved": true}, {"id": "pocket_watch", "collateral": true}]:
		owns.inventory = [entry, "bag"]
		_expect(_view(owns, "june").is_empty(), "Any carried Pocket Watch, including reserved/dictionary entries, excludes June's sale.")
	owns.inventory = ["bag"]
	owns.current_environment["home_containers"] = [{"id": "closet", "items": ["pocket_watch"]}]
	_expect(not _view(owns, "june").is_empty(), "Stored watches do not block June's specifically carried-watch condition.")
	owns.bankroll = 4
	_expect(_view(owns, "june").is_empty(), "June requires at least five cash before showing the offer.")


func _check_sable() -> void:
	var run := _winner("sable")
	if run == null:
		return
	run.bankroll = 0
	var protected := {"id": "broken_cufflinks", "reserved": true}
	run.inventory = [protected, "broken_cufflinks", "bag"]
	var clock := run.game_clock_minutes
	var turns := int(run.current_environment.get("turns", 0))
	var actions := int(run.event_cadence.get("action_index", 0))
	_expect(not _view(run, "sable").is_empty(), "Sable's free repair is eligible with zero cash in an active run.")
	var review := _view(run, "sable")
	_expect(str(review.get("summary", "")).contains("$0") and str(review.get("summary", "")).contains("45 minutes") and str(review.get("summary", "")).contains("Broken Cufflinks") and str(review.get("summary", "")).contains("Cooler's Cufflinks"), "Sable's review shows free cost, full time, consumed item and gained item before acceptance.")
	var result := _resolve(run, "sable")
	_expect(bool(result.get("ok", false)) and run.bankroll == 0 and run.game_clock_minutes == clock + 45, "Sable charges no cash and advances exactly forty-five minutes.")
	_expect(run.inventory == [protected, "bag", "coolers_cufflinks"], "Sable consumes exactly one available carried Broken Cufflinks and grants the repaired item, retaining reserved and unrelated items.")
	_expect(run.item_effect_total("blackjack_failed_peek_heat_absorb") == 1, "Sable's canonical item grant activates the repaired cufflinks' normal effect.")
	_expect(int(run.current_environment.get("turns", 0)) == turns and int(run.event_cadence.get("action_index", 0)) == actions, "Sable invents no action turns or extra default time.")
	var blocked := _winner("sable")
	if blocked == null:
		return
	for entry in [{"id": "broken_cufflinks", "reserved": true}, {"id": "broken_cufflinks", "locked": true}, {"id": "broken_cufflinks", "collateral": true}, {"id": "broken_cufflinks", "reserved_for": "delivery"}]:
		blocked.inventory = [entry, "bag"]
		_expect(_view(blocked, "sable").is_empty(), "Sable cannot consume reserved, locked or collateral source items.")
	blocked.inventory = ["bag"]
	blocked.current_environment["home_containers"] = [{"id": "drawer", "items": ["broken_cufflinks"]}]
	_expect(_view(blocked, "sable").is_empty(), "Sable cannot repair an item from home storage.")
	for target in ["coolers_cufflinks", {"id": "coolers_cufflinks"}, {"id": "coolers_cufflinks", "reserved": true}]:
		blocked.inventory = ["broken_cufflinks", target]
		_expect(_view(blocked, "sable").is_empty(), "An already carried repaired target prevents Sable's duplicate grant.")
	blocked.inventory = ["broken_cufflinks", "bag"]
	blocked.debt = [{"id": "pawned_other_pair", "status": "active", "collateral_item_id": "broken_cufflinks"}]
	_expect(not _view(blocked, "sable").is_empty(), "A separately reacquired available pair remains repairable while another pair is pawn collateral.")


func _check_shared_cycle_and_expiry() -> void:
	var punchline := _fresh("sable", "SABLE-SHARED-VENUE-ROLL", 720, "small_underground_casino")
	var queen := _fresh("sable", "SABLE-SHARED-VENUE-ROLL", 720, "delta_queen")
	OfferModel.synchronize(punchline)
	OfferModel.synchronize(queen)
	_expect(_record(punchline, "sable").get("cycle_id") == _record(queen, "sable").get("cycle_id") and _record(punchline, "sable").get("roll") == _record(queen, "sable").get("roll"), "Sable's first encounter uses the same game-day roll in either venue.")
	var closing := _winner("sable", 1440 + 135, "delta_queen")
	if closing != null:
		_expect(not _view(closing, "sable").is_empty(), "Sable is eligible exactly forty-five minutes before Delta Queen closes.")
		closing.advance_game_clock_minutes(1)
		_expect(_view(closing, "sable").is_empty(), "Sable is unavailable forty-four minutes before Delta Queen closes.")
	var run := _winner("sable", 720, "small_underground_casino")
	if run != null:
		var before := _record(run, "sable").duplicate(true)
		var result := _resolve(run, "sable")
		_expect(bool(result.get("ok", false)), "Sable's first-venue repair commits.")
		run.set_environment(_environment("delta_queen", run.game_clock_minutes))
		run.inventory = ["broken_cufflinks", "bag"]
		_expect(_view(run, "sable").is_empty() and _record(run, "sable").get("cycle_id") == before.get("cycle_id") and _record(run, "sable").get("roll") == before.get("roll"), "Sable has one shared game-day roll and claim across both venues.")
		var restored := _restore(run)
		_expect(_view(restored, "sable").is_empty() and str(_record(restored, "sable").get("status", "")) == "accepted", "Sable's cross-venue claim survives save-load even after the repaired item leaves inventory.")
	for character in ["june", "sable"]:
		var departure := _winner(character)
		if departure == null:
			continue
		var original := departure.current_environment.duplicate(true)
		var roll: Variant = _record(departure, character).get("roll")
		departure.set_environment(_environment("back_alley", departure.game_clock_minutes))
		departure.set_environment(original)
		_expect(_view(departure, character).is_empty() and _record(departure, character).get("roll") == roll, "Departure expires unclaimed %s without a reentry reroll." % character)
		var day_change := _winner(character, 1430)
		if day_change != null:
			var cycle := str(_record(day_change, character).get("cycle_id", ""))
			day_change.advance_game_clock_minutes(11)
			OfferModel.synchronize(day_change)
			_expect(str(_record(day_change, character).get("cycle_id", "")) != cycle, "%s rotates at the game-day boundary." % character)
		var declined := _winner(character)
		if declined != null:
			var cash := declined.bankroll
			var minute := declined.game_clock_minutes
			_resolve(declined, character, false)
			_expect(declined.bankroll == cash and declined.game_clock_minutes == minute and _view(declined, character).is_empty(), "Declining %s resolves the cycle without a penalty." % character)


func _check_stale_selection() -> void:
	for character in ["june", "sable"]:
		var run := _winner(character)
		if run == null:
			continue
		var offer := _view(run, character)
		run.inventory.append("pocket_watch" if character == "june" else "coolers_cufflinks")
		var before := run.to_dict()
		var rejected := OfferModel.resolve(run, library, str(offer.get("id", "")), offer.get("token", {}), true)
		_expect(not bool(rejected.get("ok", false)) and run.to_dict() == before, "A stale %s selection cannot create a duplicate item or apply its cost." % character)
	var june := _winner("june")
	if june != null:
		var sale := _view(june, "june")
		june.bankroll = 4
		var cash_clock := june.game_clock_minutes
		var invalid := OfferModel.resolve(june, library, str(sale.get("id", "")), sale.get("token", {}), true)
		_expect(not bool(invalid.get("ok", false)) and june.bankroll == 4 and june.game_clock_minutes == cash_clock and _item_count(june, "pocket_watch") == 0, "A stale June quote revalidates cash before charging or granting.")
	var sable := _winner("sable")
	if sable != null:
		var repair := _view(sable, "sable")
		sable.inventory = ["bag"]
		var invalid := OfferModel.resolve(sable, library, str(repair.get("id", "")), repair.get("token", {}), true)
		_expect(not bool(invalid.get("ok", false)) and _item_count(sable, "coolers_cufflinks") == 0, "A stale Sable quote cannot repair a missing source item.")


func _check_clock_consequences() -> void:
	var june := _winner("june", 1430)
	if june != null:
		june.initialize_home_from_profile(library.environment_archetype("motel_room"), "test_home", {"tenure": {"type": "stay", "prepaid_days": 1}})
		june.active_delivery_run = DeliveryRunModelScript.begin({"run_id": "batch_two_deadline", "mode": "package", "start_node_id": june.current_world_node_id(), "initial_cargo_state": "carried", "targets": [{"node_id": "destination", "label": "Destination"}], "deadline_kind": "clock", "started_game_clock_minutes": 1430, "deadline_minutes": 5, "consumer_payload": {"failure": {"flags": {"batch_two_deadline_applied": true}}}}, 0)
		_expect(june.delivery_has_active_run(), "The deadline fixture contains a canonical active delivery before offer acceptance.")
		var result := _resolve(june, "june")
		_expect(bool(result.get("ok", false)) and june.game_clock_minutes == 1445 and not june.home_is_active(), "June's time applies ordinary midnight home rollover.")
		_expect(bool(june.narrative_flags.get("batch_two_deadline_applied", false)) and str(june.active_delivery_run.get("status", "")) == "resolved", "June's time resolves canonical delivery deadlines and consequences.")
	var sable := _winner("sable", 1440 + 170, "small_underground_casino")
	if sable != null:
		sable._set_grand_casino_atm_debt(100)
		sable.grand_casino_atm_interest_boundary_index = -1
		_resolve(sable, "sable")
		_expect(sable.game_clock_minutes == 1655 and sable.grand_casino_atm_debt() == 105, "Sable's forty-five minutes apply ordinary 03:00 interest exactly once.")


func _check_rejected_transactions() -> void:
	for character in ["june", "sable"]:
		var source := _winner(character)
		if source == null:
			continue
		for rejection_kind in ["clock", "flush"]:
			var run: RunState = RejectingClockRun.new() if rejection_kind == "clock" else RejectingFlushRun.new()
			run.from_dict(source.to_dict())
			var offer := _view(run, character)
			_expect(not offer.is_empty(), "The restored %s fixture reaches the injected %s failure with an eligible offer." % [character, rejection_kind])
			var before := run.to_dict()
			var rejected := OfferModel.resolve(run, library, str(offer.get("id", "")), offer.get("token", {}), true)
			_expect(not bool(rejected.get("ok", false)) and run.to_dict() == before, "A rejected %s consequence rolls back %s's cost, source removal, grant, time, claim and story." % [rejection_kind, character])
