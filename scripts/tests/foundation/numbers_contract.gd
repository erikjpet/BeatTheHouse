class_name NumbersContract
extends RefCounted

const NumbersModelScript := preload("res://scripts/core/numbers_model.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const TownStateScript := preload("res://scripts/core/town_state.gd")
const PoliceSweepModelScript := preload("res://scripts/core/police_sweep_model.gd")


static func run(failures: Array) -> void:
	_check_data_and_closes(failures)
	_check_read_purity_and_boundary_determinism(failures)
	_check_slip_lifecycle_and_confiscation(failures)
	_check_hidden_discovery_and_race(failures)
	_check_physical_travel_race(failures)
	_check_silas_availability_seam(failures)
	_check_fix_and_leak_economy(failures)
	_check_runstate_fix_chain(failures)
	_check_repeated_leak_rumors(failures)
	_check_sampled_ev_bands(failures)
	_check_runner_outcomes(failures)
	_check_runner_pause_production_path(failures)
	_check_swept_collection_consequences(failures)
	_check_consequences_and_independence(failures)
	_check_midstate_save_load(failures)
	_check_sweep_reroute_determinism(failures)


static func _check_data_and_closes(failures: Array) -> void:
	var config := NumbersModelScript.tuning()
	if int(config.get("schema_version", 0)) != 1:
		failures.append("Numbers data schema version is missing.")
	var expected := {
		"small_underground_casino": -3,
		"bar": -2,
		"motel": -1,
		"gas_station_casino": 2,
		"corner_store": 4,
	}
	var seen := {}
	for venue_value in _dictionary_array(config.get("venues", [])):
		seen[str(venue_value.get("id", ""))] = int(venue_value.get("close_offset_from_post_actions", 99))
	if seen != expected:
		failures.append("Numbers signed close ordering drifted: %s." % JSON.stringify(seen))
	var rumors := _load_array_first("res://data/town/rumors.json")
	if not _string_array(rumors.get("fact_classes", [])).has("numbers_superstition") or str(rumors.get("truth_policy", "")).find("sole non-factual class") < 0:
		failures.append("Numbers superstition is not documented as the sole non-factual rumor class.")
	var archetypes := _load_array("res://data/environments/archetypes.json")
	var desk_found := false
	var poker_found := false
	var seam_clear := false
	for archetype in archetypes:
		if str(archetype.get("id", "")) != "small_underground_casino":
			continue
		var back_room := _dictionary(_dictionary(archetype.get("layers", {})).get("back_room", {}))
		var layout := _dictionary(back_room.get("layout", {}))
		desk_found = _dictionary_array_from_positions(layout.get("event_spots", [])).has({"x": 680, "y": 240}) \
			and _string_array(back_room.get("required_event_ids", [])).has("numbers_desk")
		var game_spots: Array = _dictionary_array_from_positions(layout.get("game_spots", []))
		var game_ids: Array = _string_array(back_room.get("game_ids", []))
		for game_id_value in _string_array(back_room.get("game_pool", [])) + _string_array(back_room.get("required_game_ids", [])):
			if not game_ids.has(game_id_value):
				game_ids.append(game_id_value)
		poker_found = game_spots.has({"x": 450, "y": 218}) and game_ids.has("crew_draw_poker")
		seam_clear = desk_found and Vector2(450, 218).distance_to(Vector2(680, 240)) >= 160.0
	if not desk_found:
		failures.append("Numbers minimal L3 desk is not fixed at the accepted [680,240] spot.")
	if not poker_found or not seam_clear:
		failures.append("Combined L3 fixture does not preserve reachable, separated Poker [450,218] and Numbers [680,240] spots.")


static func _check_read_purity_and_boundary_determinism(failures: Array) -> void:
	var first: NumbersModel = NumbersModelScript.new()
	first.reset(71623)
	var before := JSON.stringify(first.snapshot())
	var public_status := first.status()
	if JSON.stringify(first.snapshot()) != before:
		failures.append("Numbers status read materialized a future draw or mutated saved state.")
	for hidden_key in ["knowledge", "knowledge_assembled", "fix", "leak", "collection"]:
		if public_status.has(hidden_key):
			failures.append("Numbers public status leaked hidden field %s." % hidden_key)
	first.advance_to(15)
	if not _dictionary(first.snapshot().get("draws_by_day", {})).is_empty():
		failures.append("Numbers persisted the handle before its post boundary.")
	var around_post := first.snapshot()
	var restored: NumbersModel = NumbersModelScript.new()
	restored.restore(around_post, 71623)
	var events_a := first.advance_to(16)
	var events_b := restored.advance_to(16)
	if JSON.stringify(events_a) != JSON.stringify(events_b) or JSON.stringify(first.snapshot()) != JSON.stringify(restored.snapshot()):
		failures.append("Numbers save/load around post time changed deterministic draw timing.")
	if _dictionary(first.snapshot().get("draws_by_day", {})).size() != 1 or str(_first_event(events_a, "numbers_post").get("number", "")).length() != 3:
		failures.append("Numbers did not persist exactly one three-digit handle at the post boundary.")
	var repeat: NumbersModel = NumbersModelScript.new()
	repeat.reset(71623)
	repeat.advance_to(16)
	if JSON.stringify(repeat.snapshot().get("draws_by_day", {})) != JSON.stringify(first.snapshot().get("draws_by_day", {})):
		failures.append("Same seed and actions produced a different Numbers handle.")


static func _check_slip_lifecycle_and_confiscation(failures: Array) -> void:
	for venue_value in _dictionary_array(NumbersModelScript.tuning().get("venues", [])):
		var venue_id := str(venue_value.get("id", ""))
		var model: NumbersModel = NumbersModelScript.new()
		model.reset(90210)
		var close := model.close_action(venue_id, 0)
		model.advance_to(close - 1)
		var accepted := model.buy_slip(venue_id, "123", 2, "box")
		if not bool(accepted.get("ok", false)):
			failures.append("Numbers rejected a slip one boundary before %s close." % venue_id)
		model.advance_to(close)
		if bool(model.buy_slip(venue_id, "123", 2, "box").get("ok", false)):
			failures.append("Numbers accepted a slip at/after %s close." % venue_id)
	var confiscation: NumbersModel = NumbersModelScript.new()
	confiscation.reset(44)
	confiscation.buy_slip("bar", "111", 3, "straight")
	var confiscated := confiscation.confiscate_open_slips("test_sweep")
	if int(confiscated.get("count", 0)) != 1 or confiscation.open_slip_count() != 0:
		failures.append("Numbers sweep confiscation did not remove open slip cargo.")
	var settle: NumbersModel = NumbersModelScript.new()
	settle.reset(88)
	var winning := str(_dictionary(settle.call("_handle_record_at_boundary", 0)).get("number", "000"))
	settle.buy_slip("bar", winning, 2, "straight")
	var settlement_events := settle.advance_to(21)
	var settlement := _first_event(settlement_events, "numbers_settlement")
	if int(settlement.get("payout", 0)) != 1000 or settle.open_slip_count() != 0:
		failures.append("Numbers straight slip did not settle at its documented multiplier.")


static func _check_hidden_discovery_and_race(failures: Array) -> void:
	var solo: NumbersModel = NumbersModelScript.new()
	solo.reset(5150)
	solo.hear_staggered_close_rumor("numbers_stagger:gas_late")
	solo.hear_staggered_close_rumor("numbers_stagger:corner_late")
	if bool(_dictionary(solo.internal_status().get("knowledge", {})).get("assembled", false)):
		failures.append("Numbers discovery assembled without the Silas encounter.")
	solo.buy_silas_tip(false)
	if not bool(_dictionary(solo.internal_status().get("knowledge", {})).get("assembled", false)):
		failures.append("Numbers rumor chain plus Silas tip did not assemble hidden knowledge.")
	solo.advance_to(16)
	var number := solo.reveal_number(0, "punchline_post")
	var success := solo.buy_slip("corner_store", number, 10, "straight", number)
	if not bool(success.get("ok", false)) or not bool(_dictionary(success.get("slip", {})).get("past_post", false)):
		failures.append("Zero-trust solo past-post did not succeed from post source to an open late book.")
	solo.advance_to(20)
	if bool(solo.buy_slip("corner_store", number, 10, "straight", number).get("ok", false)):
		failures.append("Solo past-post race still succeeded at the corner close boundary.")


static func _check_physical_travel_race(failures: Array) -> void:
	var inactive: RunState = RunStateScript.new()
	inactive.start_new("NUMBERS-TRAVEL-INACTIVE")
	inactive.current_environment = {
		"id": "motel", "archetype_id": "motel", "world_node_id": "motel", "turns": 0,
		"scenario_state": {"phase": "generated", "clock": 0},
	}
	var inactive_before := JSON.stringify(inactive.to_dict())
	var inactive_cost := inactive.advance_numbers_past_post_travel_actions(16)
	if inactive_cost != 0 or JSON.stringify(inactive.to_dict()) != inactive_before:
		failures.append("Inactive Numbers changed ordinary travel state instead of remaining byte-identical.")
	var fast = _zero_trust_posted_run("NUMBERS-TRAVEL-FAST")
	fast.set_environment({
		"id": "gas_station_casino", "archetype_id": "gas_station_casino", "world_node_id": "gas_station_casino", "turns": 0,
		"scenario_state": {"phase": "generated", "clock": 0},
	})
	var fast_local_before := JSON.stringify(fast.current_environment)
	var fast_global_before := int(fast.numbers_state.action_index)
	var fast_cost := fast.advance_numbers_past_post_travel_actions(8)
	var fast_number := str(fast.numbers_status().get("published_number", ""))
	var fast_buy := fast.numbers_buy_slip(fast_number, 10, "straight")
	if fast_cost != 1 or int(fast.numbers_state.action_index) != fast_global_before + 1 or JSON.stringify(fast.current_environment) != fast_local_before or not bool(fast_buy.get("ok", false)) or not bool(_dictionary(fast_buy.get("slip", {})).get("past_post", false)):
		failures.append("An eight-minute physical trip did not reach the Gas book before its late close.")
	var slow = _zero_trust_posted_run("NUMBERS-TRAVEL-SLOW")
	slow.set_environment({"id": "gas_station_casino", "archetype_id": "gas_station_casino", "world_node_id": "gas_station_casino", "turns": 0})
	var slow_cost := slow.advance_numbers_past_post_travel_actions(9)
	var slow_number := str(slow.numbers_status().get("published_number", ""))
	var slow_buy := slow.numbers_buy_slip(slow_number, 10, "straight")
	if slow_cost != 2 or bool(slow_buy.get("ok", false)):
		failures.append("A nine-minute physical trip did not ceil to two ticks and miss the Gas book's close boundary.")
	var local_room = _zero_trust_posted_run("NUMBERS-TRAVEL-LOCAL-ROOM")
	var local_room_before := JSON.stringify(local_room.to_dict())
	if local_room.advance_numbers_past_post_travel_actions(16, true) != 0 or JSON.stringify(local_room.to_dict()) != local_room_before:
		failures.append("Local casino-room travel consumed the opt-in Numbers street-race clock.")
	var arrival: RunState = RunStateScript.new()
	arrival.start_new("NUMBERS-PUNCHLINE-ARRIVAL")
	arrival.current_environment = {"id": "bar", "archetype_id": "bar", "world_node_id": "bar", "turns": 0}
	arrival.advance_environment_turns(arrival.numbers_state.post_action(0))
	if not str(arrival.numbers_status().get("published_number", "")).is_empty():
		failures.append("The Punchline handle leaked before the player reached its physical board.")
	arrival.set_environment({"id": "small_underground_casino", "archetype_id": "small_underground_casino", "world_node_id": "small_underground_casino", "turns": 0})
	if str(arrival.numbers_status().get("published_number", "")).length() != 3:
		failures.append("Arriving at the Punchline after post did not expose its public three-digit board.")


static func _check_silas_availability_seam(failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("NUMBERS-SILAS-SURFACE")
	var first_view: Dictionary = run_state.numbers_silas_status()
	if bool(first_view.get("handle_available", true)) or first_view.keys() != ["handle_available"]:
		failures.append("First Silas view advertised hidden handle knowledge or leaked extra discovery state.")
	var silas_node := run_state.traveler_node("silas_snitch")
	run_state.current_environment = {"id": silas_node, "archetype_id": silas_node, "world_node_id": silas_node, "turns": 0}
	var bankroll_before := run_state.bankroll
	if bool(run_state.numbers_buy_silas_tip(true).get("ok", false)) or run_state.bankroll != bankroll_before:
		failures.append("Production Silas API sold the handle before hidden discovery.")
	run_state.numbers_state.hear_staggered_close_rumor("numbers_stagger:gas_late")
	run_state.numbers_state.hear_staggered_close_rumor("numbers_stagger:corner_late")
	run_state.numbers_state.buy_silas_tip(false)
	if bool(run_state.numbers_silas_status().get("handle_available", true)):
		failures.append("Silas handle exchange appeared before the authored post boundary.")
	run_state.numbers_state.advance_to(run_state.numbers_state.post_action(0))
	if not bool(run_state.numbers_silas_status().get("handle_available", false)):
		failures.append("Silas handle exchange did not unlock after genuine rumor-plus-tip discovery and post timing.")
	if not bool(run_state.numbers_buy_silas_tip(true).get("ok", false)):
		failures.append("Production Silas API rejected the discovered, correctly timed handle exchange.")
	if bool(run_state.numbers_silas_status().get("handle_available", true)):
		failures.append("Silas offered the same handle again after it was already known.")


static func _check_fix_and_leak_economy(failures: Array) -> void:
	var strong = _completed_fix(222, true, {"small_underground_casino": 18, "bar": 16, "motel": 14, "gas_station_casino": 12})
	var weak = _completed_fix(333, false, {"small_underground_casino": 4, "bar": 4, "motel": 4})
	var strong_payday := _first_event(strong.get("events", []), "numbers_fix_payday")
	var weak_payday := _first_event(weak.get("events", []), "numbers_fix_payday")
	if int(strong_payday.get("player_cut", 0)) <= int(weak_payday.get("player_cut", 0)) or int(weak_payday.get("player_cut", 0)) <= 0:
		failures.append("Numbers fix cut did not stay positive and scale with bribe/camouflage performance.")
	var abort: NumbersModel = NumbersModelScript.new()
	abort.reset(8)
	abort.fix_unlock(true)
	abort.fix_begin_bribe()
	var aborted := abort.fix_record_bribe(false)
	if not bool(aborted.get("aborted", false)) or str(_dictionary(aborted.get("fix", {})).get("status", "")) != "aborted":
		failures.append("Numbers failed bribe did not abort cleanly for later retry.")
	var leaked: NumbersModel = strong.get("model") as NumbersModel
	var leak_day := int(_dictionary(strong_payday.get("fix", {})).get("target_day", 1)) + 1
	var leak_events: Array = leaked.advance_to(leaked.day_start_action(leak_day))
	var leak := _dictionary(_first_event(leak_events, "numbers_leak_active").get("leak", {}))
	if str(leak.get("number", "")).is_empty() or int(leak.get("strictness_delta", 0)) <= 0 or int(leak.get("declared_pool_multiplier_percent", 100)) <= 100:
		failures.append("Numbers next-day leak did not carry number, pool growth, and strictness.")
	var baseline: NumbersModel = NumbersModelScript.new()
	baseline.reset(999)
	var stricter: NumbersModel = NumbersModelScript.new()
	stricter.reset(999)
	stricter.active_leak = {"strictness_delta": 3}
	if stricter.detection_chance(10, 1) <= baseline.detection_chance(10, 1):
		failures.append("Numbers leak strictness did not increase production detection odds.")
	var base_payout := _winning_straight_payout_with_leak(1001, {})
	var crowded_payout := _winning_straight_payout_with_leak(1001, {"declared_pool_multiplier_percent": 225})
	if crowded_payout >= base_payout or crowded_payout <= 0:
		failures.append("Numbers leak pile-on did not consume the capped declared payout pool.")
	var strong_slips := _fix_slips(_dictionary(strong_payday.get("fix", {})), (strong.get("model") as NumbersModel).slips)
	var strong_slip_payout := 0
	for slip_value in strong_slips:
		strong_slip_payout += int(_dictionary(slip_value).get("payout", 0))
	if strong_slips.size() != 4 or strong_slip_payout <= 0:
		failures.append("Numbers camouflage did not create and settle one real winning fixed-number slip per chosen book.")
	var over_cap: NumbersModel = NumbersModelScript.new()
	over_cap.reset(19)
	over_cap.fix_unlock(true)
	over_cap.fix_begin_bribe()
	over_cap.fix_record_bribe(true)
	if bool(over_cap.fix_allocate({"bar": 21, "motel": 1, "corner_store": 1}).get("ok", false)):
		failures.append("Numbers camouflage bypassed the ordinary per-slip stake cap.")


static func _check_runstate_fix_chain(failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("NUMBERS-PRODUCTION-FIX")
	run_state.current_environment = {"id": "small_underground_casino", "archetype_id": "small_underground_casino", "world_node_id": "small_underground_casino", "turns": 0}
	run_state.crew_add_trust("crew_lucky", 60, "numbers_fixture")
	run_state.crew_add_trust("crew_mags", 60, "numbers_fixture")
	var begun: Dictionary = run_state.numbers_begin_fix_bribe()
	if not bool(begun.get("ok", false)):
		failures.append("Made-rank production desk could not begin the real Streets fix package.")
		return
	var board: Dictionary = _dictionary(run_state.active_streets_run.get("board", {})).duplicate(true)
	board["patrols"] = []
	run_state.active_streets_run["board"] = board
	run_state.active_streets_run["player"] = _dictionary(board.get("destination", {})).duplicate(true)
	var delivered: Dictionary = run_state.streets_apply_action({"verb": "wait"})
	if not bool(delivered.get("resolved", false)) or str(run_state.numbers_desk_status().get("fix_stage", "")) != "camouflage":
		failures.append("Successful production Streets delivery did not hand the fix into camouflage allocation.")
		return
	var allocations: Dictionary = {"small_underground_casino": 18, "bar": 16, "motel": 14, "gas_station_casino": 12}
	var bankroll_before := run_state.bankroll
	run_state.bankroll = 59
	var unfunded_snapshot := JSON.stringify(run_state.numbers_state.snapshot())
	var unfunded: Dictionary = run_state.numbers_fix_allocate(allocations)
	if bool(unfunded.get("ok", false)) or run_state.bankroll != 59 or JSON.stringify(run_state.numbers_state.snapshot()) != unfunded_snapshot:
		failures.append("An unfunded production camouflage attempt mutated bankroll or Numbers state.")
	run_state.bankroll = bankroll_before
	var result: Dictionary = run_state.numbers_fix_allocate(allocations)
	if not bool(result.get("ok", false)) or run_state.bankroll != bankroll_before - 60 or int(result.get("slip_count", 0)) != 4 or result.has("fix"):
		failures.append("Production fix allocation did not charge $60, create four slips, or keep the fixed handle private.")
		return
	var target_day := int(run_state.numbers_state.fix_state.get("target_day", 1))
	run_state.advance_environment_turns(run_state.numbers_state.settlement_action(target_day) - int(run_state.numbers_state.action_index))
	if run_state.bankroll <= bankroll_before or str(run_state.numbers_state.fix_state.get("status", "")) != "completed":
		failures.append("Production fix settlement did not pay real slip winnings alongside the performance-scaled crew cut.")


static func _check_repeated_leak_rumors(failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("NUMBERS-REPEATED-LEAK")
	run_state.numbers_state.reset(1)
	run_state.current_environment = {"id": "corner_store", "archetype_id": "corner_store", "world_node_id": "corner_store", "turns": 0}
	run_state.numbers_state.hear_staggered_close_rumor("numbers_stagger:gas_late")
	run_state.numbers_state.hear_staggered_close_rumor("numbers_stagger:corner_late")
	run_state.numbers_state.buy_silas_tip(false)
	for day in range(2):
		var post := run_state.numbers_state.post_action(day)
		run_state.call("_apply_numbers_events", run_state.numbers_state.advance_to(post))
		var number := run_state.numbers_state.reveal_number(day, "punchline_post")
		var purchase: Dictionary = run_state.numbers_state.buy_slip("corner_store", number, 10, "straight", number)
		if not bool(purchase.get("ok", false)) or bool(_dictionary(purchase.get("slip", {})).get("detected", true)):
			failures.append("Seeded repeated-leak fixture did not create an undetected qualifying past-post success.")
			return
		run_state.call("_apply_numbers_events", run_state.numbers_state.advance_to(run_state.numbers_state.settlement_action(day)))
		if day == 0:
			run_state.call("_apply_numbers_events", run_state.numbers_state.advance_to(run_state.numbers_state.day_start_action(1)))
	run_state.call("_apply_numbers_events", run_state.numbers_state.advance_to(run_state.numbers_state.day_start_action(2)))
	var leak := run_state.numbers_state.active_leak
	var facts := run_state.rumor_facts("numbers_whisper")
	var registered := false
	for fact_value in facts:
		var fact := _dictionary(fact_value)
		var payload := _dictionary(fact.get("payload", {}))
		if str(fact.get("source_id", "")) == "numbers_fix_leak" and str(payload.get("number", "")).length() == 3 and str(payload.get("pattern", "")).length() == 3 and int(payload.get("strictness_delta", 0)) >= 2:
			registered = true
			break
	if int(leak.get("successes", 0)) != 2 or int(leak.get("declared_pool_multiplier_percent", 100)) < 150 or not registered:
		failures.append("Repeated qualifying wins did not escalate and register the next-day number/pattern/strictness rumor.")


static func _check_sampled_ev_bands(failures: Array) -> void:
	var sample_count := 5000
	var straight_payout := 0
	var box_payout := 0
	for seed_value in range(1, sample_count + 1):
		var straight_model: NumbersModel = NumbersModelScript.new()
		straight_model.reset(seed_value)
		straight_model.buy_slip("bar", "000", 1, "straight")
		straight_payout += int(_first_event(straight_model.advance_to(21), "numbers_settlement").get("payout", 0))
		var box_model: NumbersModel = NumbersModelScript.new()
		box_model.reset(seed_value)
		box_model.buy_slip("bar", "123", 1, "box")
		box_payout += int(_first_event(box_model.advance_to(21), "numbers_settlement").get("payout", 0))
	var straight_net := float(straight_payout - sample_count) / float(sample_count)
	var box_net := float(box_payout - sample_count) / float(sample_count)
	if straight_net >= 0.0 or box_net >= 0.0:
		failures.append("Seed-sampled honest straight/box play escaped its negative EV band: %.3f / %.3f." % [straight_net, box_net])
	var runner_cash := 0
	var fix_cut := 0
	var samples := 24
	for sample in range(samples):
		var runner := _runner_fixture("NUMBERS-EV-RUNNER-%d" % sample)
		runner_cash += int(_dictionary(runner.get("started", {})).get("pay", 0))
		var fixed := _completed_fix(700 + sample, true, {"bar": 20, "motel": 20, "corner_store": 20})
		fix_cut += int(_first_event(fixed.get("events", []), "numbers_fix_payday").get("player_cut", 0))
	var bands := _dictionary(NumbersModelScript.tuning().get("ev_bands", {}))
	if float(runner_cash) / float(samples) < float(bands.get("runner_expected_cash_min", 18)) or float(fix_cut) / float(samples) < float(bands.get("fix_expected_cut_min", 24)):
		failures.append("Seed-sampled runner cash or fix cut fell below the authored positive EV bands.")
	var undetected_count := 0
	var undetected_net := 0
	for past_seed in range(1, 101):
		var past_model: NumbersModel = NumbersModelScript.new()
		past_model.reset(past_seed)
		past_model.hear_staggered_close_rumor("numbers_stagger:gas_late")
		past_model.hear_staggered_close_rumor("numbers_stagger:corner_late")
		past_model.buy_silas_tip(false)
		past_model.advance_to(past_model.post_action(0))
		var handle := past_model.reveal_number(0, "punchline_post")
		var purchase := past_model.buy_slip("corner_store", handle, 10, "straight", handle)
		if bool(_dictionary(purchase.get("slip", {})).get("detected", true)):
			continue
		var event := _first_event(past_model.advance_to(past_model.settlement_action(0)), "numbers_past_post_success")
		if not event.is_empty():
			undetected_count += 1
			undetected_net += int(event.get("payout", 0)) - 10
	var past_post_net_per_dollar := float(undetected_net) / float(maxi(1, undetected_count * 10))
	if past_post_net_per_dollar < float(bands.get("undetected_past_post_net_per_dollar_min", 40)):
		failures.append("Undetected past-post sampled return fell below its authored positive EV band.")


static func _check_runner_pause_production_path(failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("NUMBERS-PAUSE")
	run_state.current_environment = {"id": "bar", "archetype_id": "bar", "turns": 0}
	run_state.town_state.police_sweep.swept_windows_by_node["corner_store"] = {"node_id": "corner_store", "start_action": 0, "end_action": 4}
	run_state.town_state.police_sweep.action_index = 0
	var stops := [{"id": "corner", "node_id": "corner_store", "label": "Corner"}]
	var started: Dictionary = run_state.streets_begin_multi_stop({
		"route_id": "numbers_collection:test", "origin_node_id": "bar", "destination_node_id": "small_underground_casino",
		"stops": stops, "deadline_actions": 10, "cargo_id": "numbers_slips",
	})
	run_state.numbers_state.begin_collection(stops, 100, "")
	if not bool(started.get("ok", false)):
		failures.append("Numbers production runner fixture could not start frozen multi-stop Streets.")
		return
	var blocked := run_state.streets_apply_action({"verb": "move", "direction": {"x": 1, "y": 0}, "pace": "walk"})
	if not bool(blocked.get("paused", false)) or not bool(blocked.get("wait_available", false)):
		failures.append("Numbers swept stop did not pause travel while offering a boundary wait.")
	var before_action := run_state.town_state.action_index
	var waited := run_state.streets_apply_action({"verb": "wait"})
	if not bool(waited.get("ok", false)) or run_state.town_state.action_index != before_action + 1 or str(run_state.numbers_state.collection_state.get("status", "")) != "active":
		failures.append("Numbers swept-stop wait did not advance town/sweep time while preserving collection cargo.")


static func _check_runner_outcomes(failures: Array) -> void:
	var success = _runner_fixture("NUMBERS-RUNNER-SUCCESS")
	if not bool(success.get("ok", false)):
		failures.append("Lucky associate production route did not enter frozen multi-stop Streets.")
		return
	var success_run: RunState = success.get("run") as RunState
	var cash_before := success_run.bankroll
	var trust_before := success_run.crew_trust("crew_lucky")
	var board := _dictionary(success_run.active_streets_run.get("board", {})).duplicate(true)
	board["patrols"] = []
	success_run.active_streets_run["board"] = board
	var stops := _dictionary_array(success_run.active_streets_run.get("stops", []))
	for index in range(stops.size()):
		stops[index]["visited"] = true
	success_run.active_streets_run["stops"] = stops
	success_run.active_streets_run["player"] = _dictionary(board.get("destination", {})).duplicate(true)
	var completed := success_run.streets_apply_action({"verb": "wait"})
	if not bool(completed.get("resolved", false)) or success_run.bankroll <= cash_before or success_run.crew_trust("crew_lucky") <= trust_before:
		failures.append("On-time Numbers collection did not pay its bag percentage and Lucky trust.")
	var late = _runner_fixture("NUMBERS-RUNNER-LATE")
	var late_run: RunState = late.get("run") as RunState
	var late_trust := late_run.crew_trust("crew_lucky")
	late_run.active_streets_run["deadline_remaining"] = 1
	late_run.streets_apply_action({"verb": "wait"})
	if late_run.crew_trust("crew_lucky") >= late_trust or not late_run.crew_grievances("crew_lucky").is_empty():
		failures.append("Late Numbers collection did not hit trust cleanly without an abandonment grievance.")
	var ditched = _runner_fixture("NUMBERS-RUNNER-DITCH")
	var ditched_run: RunState = ditched.get("run") as RunState
	ditched_run.streets_apply_action({"verb": "ditch"})
	if ditched_run.crew_grievances("crew_lucky").is_empty() or str(ditched_run.crew_grievances("crew_lucky")[0].get("kind", "")) != "job_abandoned":
		failures.append("Ditched Numbers collection did not write job_abandoned.")


static func _check_swept_collection_consequences(failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("NUMBERS-SWEPT-COMPLETE")
	run_state.current_environment = {"id": "bar", "archetype_id": "bar", "world_node_id": "bar", "turns": 0}
	run_state.numbers_buy_slip("123", 3, "straight")
	run_state.crew_add_trust("crew_lucky", 30, "fixture")
	var started := run_state.numbers_begin_collection_route()
	if not bool(started.get("ok", false)):
		failures.append("Complete swept-consequence fixture could not start Lucky's collection.")
		return
	var trust_before := run_state.crew_trust("crew_lucky")
	var heat_before := run_state.suspicion_level()
	var job_id := str(started.get("job_id", ""))
	var result := _dictionary(run_state.call("_resolve_police_sweep_encounter", {"node_id": "bar", "segment_index": 0, "encounter_seed": 27}))
	var queued_ids: Array = []
	for pending_value in run_state.pending_triggered_events:
		queued_ids.append(str(_dictionary(pending_value).get("event_id", "")))
	var rumor_found := false
	for fact_value in run_state.rumor_facts("numbers_whisper"):
		if str(_dictionary(fact_value).get("source_id", "")) == "numbers_collection_swept":
			rumor_found = true
			break
	var job := _dictionary(run_state.crew_jobs.get(job_id, {}))
	var pending_ditch := bool(run_state.narrative_flags.get("numbers_collection_sweep_confiscation_pending", false))
	var forced_resolution := run_state.streets_apply_action({"verb": "wait"})
	var consequence_evidence := {
		"collection_reason": str(run_state.numbers_state.collection_state.get("reason", "")),
		"job_status": str(job.get("status", "")),
		"trust_before": trust_before,
		"trust_after": run_state.crew_trust("crew_lucky"),
		"heat_before": heat_before,
		"heat_after": run_state.suspicion_level(),
		"confiscated_count": int(_dictionary(result.get("numbers_collection_confiscated", {})).get("count", 0)),
		"bag_value": int(result.get("numbers_collection_bag_value_confiscated", 0)),
		"pending_before_ditch": pending_ditch,
		"queued_ids": queued_ids,
		"rumor_found": rumor_found,
		"forced_resolution": forced_resolution,
		"grievances": run_state.crew_grievances("crew_lucky"),
		"pending_after_ditch": bool(run_state.narrative_flags.get("numbers_collection_sweep_confiscation_pending", false)),
	}
	if str(run_state.numbers_state.collection_state.get("reason", "")) != "swept" \
		or str(job.get("status", "")) != "failed" \
		or run_state.crew_trust("crew_lucky") >= trust_before \
		or run_state.suspicion_level() < heat_before + 14 \
		or int(_dictionary(result.get("numbers_collection_confiscated", {})).get("count", 0)) != 1 \
		or int(result.get("numbers_collection_bag_value_confiscated", 0)) <= 0 \
		or not pending_ditch \
		or not queued_ids.has("numbers_lucky_swept_collection") \
		or not rumor_found \
		or not bool(forced_resolution.get("resolved", false)) \
		or not run_state.crew_grievances("crew_lucky").is_empty() \
		or bool(run_state.narrative_flags.get("numbers_collection_sweep_confiscation_pending", false)):
		failures.append("Swept Numbers collection missed a documented consequence: %s." % JSON.stringify(consequence_evidence))


static func _check_consequences_and_independence(failures: Array) -> void:
	var solo: RunState = RunStateScript.new()
	solo.start_new("NUMBERS-SOLO-DEBT")
	solo.numbers_state.reset(7)
	solo.current_environment = {"id": "corner_store", "archetype_id": "corner_store", "world_node_id": "corner_store", "turns": 0}
	solo.numbers_state.hear_staggered_close_rumor("numbers_stagger:gas_late")
	solo.numbers_state.hear_staggered_close_rumor("numbers_stagger:corner_late")
	solo.numbers_state.buy_silas_tip(false)
	solo.call("_apply_numbers_events", solo.numbers_state.advance_to(solo.numbers_state.post_action(0)))
	var detected_number := solo.numbers_state.reveal_number(0, "punchline_post")
	var detected_purchase := solo.numbers_buy_slip(detected_number, 20, "straight")
	var detected_slip := _dictionary(detected_purchase.get("slip", {}))
	if not bool(detected_purchase.get("ok", false)) or not bool(detected_slip.get("detected", false)):
		failures.append("Seed 7 did not produce the authored real past-post detection fixture.")
		return
	solo.call("_apply_numbers_events", solo.numbers_state.advance_to(solo.numbers_state.settlement_action(0)))
	if solo.debt.is_empty() or not solo.crew_grievances().is_empty():
		failures.append("Real seeded solo detection did not create production street debt without an in-colors grievance.")
	var crew: RunState = RunStateScript.new()
	crew.start_new("NUMBERS-CREW-DEBT")
	crew.numbers_state.reset(7)
	crew.crew_add_trust("crew_lucky", 1, "fixture")
	crew.current_environment = {"id": "corner_store", "archetype_id": "corner_store", "world_node_id": "corner_store", "turns": 0}
	crew.numbers_state.hear_staggered_close_rumor("numbers_stagger:gas_late")
	crew.numbers_state.hear_staggered_close_rumor("numbers_stagger:corner_late")
	crew.numbers_state.buy_silas_tip(false)
	crew.call("_apply_numbers_events", crew.numbers_state.advance_to(crew.numbers_state.post_action(0)))
	var crew_number := crew.numbers_state.reveal_number(0, "punchline_post")
	crew.numbers_buy_slip(crew_number, 20, "straight")
	crew.call("_apply_numbers_events", crew.numbers_state.advance_to(crew.numbers_state.settlement_action(0)))
	if crew.debt.is_empty() or crew.crew_grievances("crew_knuckles").size() != 1 or str(crew.crew_grievances("crew_knuckles")[0].get("kind", "")) != "numbers_past_posting_in_colors":
		failures.append("Real seeded crew-path detection missed production debt or the typed in-colors grievance.")
	var forbidden := "hei" + "st"
	for path in ["res://data/crew/numbers.json", "res://scripts/core/numbers_model.gd", "res://scripts/ui/environment_interaction_controller.gd", "res://scripts/ui/environment_interaction_view_model.gd"]:
		if FileAccess.get_file_as_string(path).to_lower().find(forbidden) >= 0:
			failures.append("Numbers implementation contains forbidden cross-system vocabulary in %s." % path)
	var run_source := FileAccess.get_file_as_string("res://scripts/core/run_state.gd")
	var numbers_begin := run_source.find("func numbers_status")
	var numbers_end := run_source.find("func streets_begin", numbers_begin)
	if numbers_begin < 0 or numbers_end <= numbers_begin or run_source.substr(numbers_begin, numbers_end - numbers_begin).to_lower().find(forbidden) >= 0:
		failures.append("Numbers-owned RunState surface contains forbidden cross-system coupling.")
	var ui_source := FileAccess.get_file_as_string("res://scripts/ui/foundation_main.gd")
	var ui_begin := ui_source.find("func _open_numbers_surface")
	var ui_end := ui_source.find("func _hide_event_choice_popup", ui_begin)
	if ui_begin < 0 or ui_end <= ui_begin or ui_source.substr(ui_begin, ui_end - ui_begin).to_lower().find(forbidden) >= 0:
		failures.append("Numbers-owned production UI surface contains forbidden cross-system coupling.")
	var untouched: RunState = RunStateScript.new()
	untouched.start_new("NUMBERS-INDEPENDENCE")
	var exercised: RunState = RunStateScript.new()
	exercised.start_new("NUMBERS-INDEPENDENCE")
	var before_projection := _independence_projection(exercised)
	exercised.current_environment = {"id": "bar", "archetype_id": "bar", "world_node_id": "bar", "turns": 0}
	exercised.numbers_buy_slip("123", 1, "box")
	exercised.advance_environment_turns(3)
	if JSON.stringify(_independence_projection(untouched)) != JSON.stringify(before_projection) or JSON.stringify(_independence_projection(exercised)) != JSON.stringify(before_projection):
		failures.append("An otherwise untouched run changed unrelated planning eligibility or flags after Numbers-only play.")


static func _check_midstate_save_load(failures: Array) -> void:
	var open_run: RunState = RunStateScript.new()
	open_run.start_new("NUMBERS-SAVE-OPEN")
	open_run.current_environment = {"id": "bar", "archetype_id": "bar", "world_node_id": "bar", "turns": 0}
	open_run.numbers_buy_slip("123", 4, "box")
	open_run.advance_environment_turns(15)
	var open_saved: Dictionary = open_run.to_dict()
	var open_saved_json := JSON.stringify(open_saved)
	var open_restored: RunState = RunStateScript.new()
	open_restored.from_dict(open_saved)
	if JSON.stringify(open_restored.numbers_state.snapshot()) != JSON.stringify(open_run.numbers_state.snapshot()) or open_restored.bankroll != open_run.bankroll:
		failures.append("RunState save/load changed the pre-post open-slip Numbers state.")
	if JSON.stringify(open_restored.to_dict()) != open_saved_json:
		failures.append("RunState save/load mutated restored town discovery facts or their registration metadata.")
	var collection_fixture := _runner_fixture("NUMBERS-SAVE-COLLECTION")
	if not bool(collection_fixture.get("ok", false)):
		failures.append("RunState save/load fixture could not start the active Lucky collection.")
		return
	var collection_run: RunState = collection_fixture.get("run") as RunState
	var collection_restored: RunState = RunStateScript.new()
	collection_restored.from_dict(collection_run.to_dict())
	if JSON.stringify(collection_restored.numbers_state.snapshot()) != JSON.stringify(collection_run.numbers_state.snapshot()) or JSON.stringify(collection_restored.streets_snapshot()) != JSON.stringify(collection_run.streets_snapshot()):
		failures.append("RunState save/load changed active Lucky collection cargo or its frozen Streets board.")
	var fix_run: RunState = RunStateScript.new()
	fix_run.start_new("NUMBERS-SAVE-FIX")
	fix_run.current_environment = {"id": "small_underground_casino", "archetype_id": "small_underground_casino", "world_node_id": "small_underground_casino", "turns": 0}
	fix_run.numbers_state.fix_unlock(true)
	fix_run.numbers_state.fix_begin_bribe()
	fix_run.numbers_state.fix_record_bribe(true, {"clean": true, "fast": true})
	fix_run.numbers_fix_allocate({"bar": 20, "motel": 20, "corner_store": 20})
	var fix_restored: RunState = RunStateScript.new()
	fix_restored.from_dict(fix_run.to_dict())
	if JSON.stringify(fix_restored.numbers_state.snapshot()) != JSON.stringify(fix_run.numbers_state.snapshot()) or fix_restored.bankroll != fix_run.bankroll:
		failures.append("RunState save/load changed funded camouflage slips in payday state.")
		return
	var target_day := int(fix_run.numbers_state.fix_state.get("target_day", 1))
	var remaining := fix_run.numbers_state.settlement_action(target_day) - int(fix_run.numbers_state.action_index)
	fix_run.advance_environment_turns(remaining)
	fix_restored.advance_environment_turns(remaining)
	if JSON.stringify(fix_restored.numbers_state.snapshot()) != JSON.stringify(fix_run.numbers_state.snapshot()) or fix_restored.bankroll != fix_run.bankroll:
		failures.append("Mid-payday save/load diverged through fixed slip settlement and crew cut.")


static func _check_sweep_reroute_determinism(failures: Array) -> void:
	var map_data := {
		"nodes": [
			{"id": "back_alley", "archetype_id": "back_alley", "tier": 1},
			{"id": "bar", "archetype_id": "bar", "tier": 1},
			{"id": "corner_store", "archetype_id": "corner_store", "tier": 1},
			{"id": "motel", "archetype_id": "motel", "tier": 1},
		],
		"edges": [{"a": "back_alley", "b": "bar"}, {"a": "bar", "b": "corner_store"}, {"a": "corner_store", "b": "motel"}],
	}
	var happening := {"start_action": 0, "end_action": 40}
	var first = PoliceSweepModelScript.new()
	first.reset(71, {"dwell_actions": [3, 3]})
	first.configure_world(map_data, happening, {"dwell_actions": [3, 3]}, 0)
	var reroute_a := first.request_reroute_toward(["corner_store", "motel"], "numbers_leak:3")
	if not bool(reroute_a.get("applied", false)):
		failures.append("Numbers leak did not live-reroute an active sweep toward a Numbers venue.")
		return
	var saved := first.snapshot()
	var restored = PoliceSweepModelScript.new()
	restored.restore(saved, 71, {"dwell_actions": [3, 3]})
	restored.configure_world(map_data, happening, {"dwell_actions": [3, 3]}, 0)
	if JSON.stringify(restored.snapshot().get("segments", [])) != JSON.stringify(first.snapshot().get("segments", [])) or JSON.stringify(restored.snapshot().get("reroute_history", [])) != JSON.stringify(first.snapshot().get("reroute_history", [])):
		failures.append("Numbers sweep reroute did not survive save/load exactly.")
	var repeat = PoliceSweepModelScript.new()
	repeat.reset(71, {"dwell_actions": [3, 3]})
	repeat.configure_world(map_data, happening, {"dwell_actions": [3, 3]}, 0)
	var reroute_b := repeat.request_reroute_toward(["corner_store", "motel"], "numbers_leak:3")
	if JSON.stringify(reroute_a) != JSON.stringify(reroute_b) or JSON.stringify(first.snapshot().get("segments", [])) != JSON.stringify(repeat.snapshot().get("segments", [])):
		failures.append("Same-seed Numbers sweep reroute replay diverged.")
	var consumer_sweep = PoliceSweepModelScript.new()
	consumer_sweep.reset(71, {"dwell_actions": [3, 3]})
	consumer_sweep.configure_world(map_data, happening, {"dwell_actions": [3, 3]}, 0)
	var consumer_run: RunState = RunStateScript.new()
	consumer_run.start_new("NUMBERS-REROUTE-CONSUMER")
	consumer_run.town_state.police_sweep = consumer_sweep
	consumer_run.call("_apply_numbers_leak", {"active_day": 1, "number": "318", "successes": 3, "sweep_reroute_requested": true})
	if consumer_sweep.reroute_history.is_empty() or not bool(_dictionary(consumer_sweep.reroute_history.back()).get("applied", false)):
		failures.append("Numbers leak production consumer did not invoke the live TownState sweep reroute seam.")


static func _completed_fix(seed_value: int, strong: bool, allocations: Dictionary) -> Dictionary:
	var model: NumbersModel = NumbersModelScript.new()
	model.reset(seed_value)
	model.fix_unlock(true)
	model.fix_begin_bribe()
	model.fix_record_bribe(true, {"clean": strong, "fast": strong})
	var allocation := model.fix_allocate(allocations)
	var target_day := int(_dictionary(allocation.get("fix", {})).get("target_day", 1))
	return {"model": model, "events": model.advance_to(model.settlement_action(target_day))}


static func _fix_slips(fix: Dictionary, slips: Array) -> Array:
	var ids := _string_array(fix.get("slip_ids", []))
	var result: Array = []
	for slip_value in slips:
		var slip := _dictionary(slip_value)
		if ids.has(str(slip.get("id", ""))) and bool(slip.get("crew_fix", false)):
			result.append(slip)
	return result


static func _zero_trust_posted_run(seed_text: String) -> RunState:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed_text)
	run_state.current_environment = {"id": "small_underground_casino", "archetype_id": "small_underground_casino", "world_node_id": "small_underground_casino", "turns": 0}
	run_state.numbers_state.hear_staggered_close_rumor("numbers_stagger:gas_late")
	run_state.numbers_state.hear_staggered_close_rumor("numbers_stagger:corner_late")
	run_state.numbers_state.buy_silas_tip(false)
	run_state.advance_environment_turns(run_state.numbers_state.post_action(0))
	return run_state


static func _independence_projection(run_state: RunState) -> Dictionary:
	var standing := run_state.crew_standing()
	var planning_key := "hei" + "st_eligibility"
	var planning_flags: Dictionary = {}
	for key_value in run_state.narrative_flags.keys():
		var key := str(key_value)
		if key.to_lower().find("hei" + "st") >= 0:
			planning_flags[key] = run_state.narrative_flags.get(key_value)
	return {
		"planning_eligibility": _dictionary(standing.get(planning_key, {})).duplicate(true),
		"planning_flags": planning_flags,
	}


static func _runner_fixture(seed_text: String) -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed_text)
	run_state.current_environment = {"id": "bar", "archetype_id": "bar", "world_node_id": "bar", "turns": 0}
	run_state.crew_add_trust("crew_lucky", 30, "fixture")
	var started := run_state.numbers_begin_collection_route()
	return {"ok": bool(started.get("ok", false)), "run": run_state, "started": started}


static func _winning_straight_payout_with_leak(seed_value: int, leak: Dictionary) -> int:
	var model: NumbersModel = NumbersModelScript.new()
	model.reset(seed_value)
	model.active_leak = leak.duplicate(true)
	var winning := str(_dictionary(model.call("_handle_record_at_boundary", 0)).get("number", "000"))
	model.buy_slip("bar", winning, 20, "straight")
	var event := _first_event(model.advance_to(21), "numbers_settlement")
	return int(event.get("payout", 0))


static func _first_event(events: Array, event_type: String) -> Dictionary:
	for event_value in events:
		if typeof(event_value) == TYPE_DICTIONARY and str((event_value as Dictionary).get("type", "")) == event_type:
			return (event_value as Dictionary).duplicate(true)
	return {}


static func _load_array(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Array if typeof(parsed) == TYPE_ARRAY else []


static func _load_array_first(path: String) -> Dictionary:
	var values := _load_array(path)
	return _dictionary(values[0]) if not values.is_empty() else {}


static func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for entry_value in value as Array:
			if typeof(entry_value) == TYPE_DICTIONARY:
				result.append((entry_value as Dictionary).duplicate(true))
	return result


static func _dictionary_array_from_positions(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for position_value in value as Array:
			if typeof(position_value) == TYPE_ARRAY and (position_value as Array).size() >= 2:
				result.append({"x": int((position_value as Array)[0]), "y": int((position_value as Array)[1])})
	return result


static func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for entry_value in value as Array:
			var text := str(entry_value).strip_edges()
			if not text.is_empty():
				result.append(text)
	return result
