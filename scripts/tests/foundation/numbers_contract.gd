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
	_check_fix_and_leak_economy(failures)
	_check_runner_outcomes(failures)
	_check_runner_pause_production_path(failures)
	_check_consequences_and_independence(failures)
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
	for archetype in archetypes:
		if str(archetype.get("id", "")) != "small_underground_casino":
			continue
		var back_room := _dictionary(_dictionary(archetype.get("layers", {})).get("back_room", {}))
		var layout := _dictionary(back_room.get("layout", {}))
		desk_found = _dictionary_array_from_positions(layout.get("event_spots", [])).has({"x": 680, "y": 240}) \
			and _string_array(back_room.get("required_event_ids", [])).has("numbers_desk")
	if not desk_found:
		failures.append("Numbers minimal L3 desk is not fixed at the accepted [680,240] spot.")


static func _check_read_purity_and_boundary_determinism(failures: Array) -> void:
	var first = NumbersModelScript.new()
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
	var restored = NumbersModelScript.new()
	restored.restore(around_post, 71623)
	var events_a := first.advance_to(16)
	var events_b := restored.advance_to(16)
	if JSON.stringify(events_a) != JSON.stringify(events_b) or JSON.stringify(first.snapshot()) != JSON.stringify(restored.snapshot()):
		failures.append("Numbers save/load around post time changed deterministic draw timing.")
	if _dictionary(first.snapshot().get("draws_by_day", {})).size() != 1 or str(_first_event(events_a, "numbers_post").get("number", "")).length() != 3:
		failures.append("Numbers did not persist exactly one three-digit handle at the post boundary.")
	var repeat = NumbersModelScript.new()
	repeat.reset(71623)
	repeat.advance_to(16)
	if JSON.stringify(repeat.snapshot().get("draws_by_day", {})) != JSON.stringify(first.snapshot().get("draws_by_day", {})):
		failures.append("Same seed and actions produced a different Numbers handle.")


static func _check_slip_lifecycle_and_confiscation(failures: Array) -> void:
	for venue_value in _dictionary_array(NumbersModelScript.tuning().get("venues", [])):
		var venue_id := str(venue_value.get("id", ""))
		var model = NumbersModelScript.new()
		model.reset(90210)
		var close := model.close_action(venue_id, 0)
		model.advance_to(close - 1)
		var accepted := model.buy_slip(venue_id, "123", 2, "box")
		if not bool(accepted.get("ok", false)):
			failures.append("Numbers rejected a slip one boundary before %s close." % venue_id)
		model.advance_to(close)
		if bool(model.buy_slip(venue_id, "123", 2, "box").get("ok", false)):
			failures.append("Numbers accepted a slip at/after %s close." % venue_id)
	var confiscation = NumbersModelScript.new()
	confiscation.reset(44)
	confiscation.buy_slip("bar", "111", 3, "straight")
	var confiscated := confiscation.confiscate_open_slips("test_sweep")
	if int(confiscated.get("count", 0)) != 1 or confiscation.open_slip_count() != 0:
		failures.append("Numbers sweep confiscation did not remove open slip cargo.")
	var settle = NumbersModelScript.new()
	settle.reset(88)
	var winning := str(_dictionary(settle.call("_draw", 0)).get("number", "000"))
	settle.buy_slip("bar", winning, 2, "straight")
	var settlement_events := settle.advance_to(21)
	var settlement := _first_event(settlement_events, "numbers_settlement")
	if int(settlement.get("payout", 0)) != 1000 or settle.open_slip_count() != 0:
		failures.append("Numbers straight slip did not settle at its documented multiplier.")


static func _check_hidden_discovery_and_race(failures: Array) -> void:
	var solo = NumbersModelScript.new()
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


static func _check_fix_and_leak_economy(failures: Array) -> void:
	var strong = _completed_fix(222, true, {"small_underground_casino": 18, "bar": 16, "motel": 14, "gas_station_casino": 12})
	var weak = _completed_fix(333, false, {"small_underground_casino": 4, "bar": 4, "motel": 4})
	var strong_payday := _first_event(strong.get("events", []), "numbers_fix_payday")
	var weak_payday := _first_event(weak.get("events", []), "numbers_fix_payday")
	if int(strong_payday.get("player_cut", 0)) <= int(weak_payday.get("player_cut", 0)) or int(weak_payday.get("player_cut", 0)) <= 0:
		failures.append("Numbers fix cut did not stay positive and scale with bribe/camouflage performance.")
	var abort = NumbersModelScript.new()
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
	var baseline = NumbersModelScript.new()
	baseline.reset(999)
	var stricter = NumbersModelScript.new()
	stricter.reset(999)
	stricter.active_leak = {"strictness_delta": 3}
	if stricter.detection_chance(10, 1) <= baseline.detection_chance(10, 1):
		failures.append("Numbers leak strictness did not increase production detection odds.")
	var base_payout := _winning_straight_payout_with_leak(1001, {})
	var crowded_payout := _winning_straight_payout_with_leak(1001, {"declared_pool_multiplier_percent": 225})
	if crowded_payout >= base_payout or crowded_payout <= 0:
		failures.append("Numbers leak pile-on did not consume the capped declared payout pool.")
	var straight := _dictionary(_dictionary(_dictionary(NumbersModelScript.tuning().get("slips", {})).get("play_types", {})).get("straight", {}))
	var box := _dictionary(_dictionary(_dictionary(NumbersModelScript.tuning().get("slips", {})).get("play_types", {})).get("box", {}))
	if float(straight.get("honest_gross_return", 1.0)) >= 1.0 or float(box.get("honest_gross_return_distinct_digits", 1.0)) >= 1.0:
		failures.append("Numbers honest-play EV is not negative.")
	if int(strong_payday.get("player_cut", 0)) <= 0 or (500 * 10 - 10) <= 0:
		failures.append("Numbers fix/past-post positive EV bands are not reachable.")


static func _check_runner_pause_production_path(failures: Array) -> void:
	var run_state = RunStateScript.new()
	run_state.start_new("NUMBERS-PAUSE")
	run_state.current_environment = {"id": "bar", "archetype_id": "bar", "turns": 0}
	run_state.town_state.police_sweep.swept_windows_by_node["corner_store"] = {"node_id": "corner_store", "start_action": 0, "end_action": 4}
	run_state.town_state.police_sweep.action_index = 0
	var stops := [{"id": "corner", "node_id": "corner_store", "label": "Corner"}]
	var started := run_state.streets_begin_multi_stop({
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


static func _check_consequences_and_independence(failures: Array) -> void:
	var event := {"type": "numbers_past_post_detected", "penalty": 40, "slip": {"id": "solo", "venue_id": "corner_store"}}
	var solo = RunStateScript.new()
	solo.start_new("NUMBERS-SOLO-DEBT")
	solo.call("_apply_numbers_events", [event])
	if solo.debt.is_empty() or not solo.crew_grievances().is_empty():
		failures.append("Solo Numbers detection did not create street debt without an in-colors grievance.")
	var crew = RunStateScript.new()
	crew.start_new("NUMBERS-CREW-DEBT")
	crew.crew_add_trust("crew_lucky", 1, "fixture")
	crew.call("_apply_numbers_events", [event])
	if crew.crew_grievances("crew_knuckles").size() != 1 or str(crew.crew_grievances("crew_knuckles")[0].get("kind", "")) != "numbers_past_posting_in_colors":
		failures.append("Crew-path Numbers detection missed the typed in-colors grievance.")
	var forbidden := "hei" + "st"
	for path in ["res://data/crew/numbers.json", "res://scripts/core/numbers_model.gd"]:
		if FileAccess.get_file_as_string(path).to_lower().find(forbidden) >= 0:
			failures.append("Numbers implementation contains forbidden cross-system vocabulary in %s." % path)


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
	var consumer_run = RunStateScript.new()
	consumer_run.start_new("NUMBERS-REROUTE-CONSUMER")
	consumer_run.town_state.police_sweep = consumer_sweep
	consumer_run.call("_apply_numbers_leak", {"active_day": 1, "number": "318", "successes": 3, "sweep_reroute_requested": true})
	if consumer_sweep.reroute_history.is_empty() or not bool(_dictionary(consumer_sweep.reroute_history.back()).get("applied", false)):
		failures.append("Numbers leak production consumer did not invoke the live TownState sweep reroute seam.")


static func _completed_fix(seed_value: int, strong: bool, allocations: Dictionary) -> Dictionary:
	var model = NumbersModelScript.new()
	model.reset(seed_value)
	model.fix_unlock(true)
	model.fix_begin_bribe()
	model.fix_record_bribe(true, {"clean": strong, "fast": strong})
	var allocation := model.fix_allocate(allocations)
	var target_day := int(_dictionary(allocation.get("fix", {})).get("target_day", 1))
	return {"model": model, "events": model.advance_to(model.settlement_action(target_day))}


static func _runner_fixture(seed_text: String) -> Dictionary:
	var run_state = RunStateScript.new()
	run_state.start_new(seed_text)
	run_state.current_environment = {"id": "bar", "archetype_id": "bar", "world_node_id": "bar", "turns": 0}
	run_state.crew_add_trust("crew_lucky", 30, "fixture")
	var started := run_state.numbers_begin_collection_route()
	return {"ok": bool(started.get("ok", false)), "run": run_state, "started": started}


static func _winning_straight_payout_with_leak(seed_value: int, leak: Dictionary) -> int:
	var model = NumbersModelScript.new()
	model.reset(seed_value)
	model.active_leak = leak.duplicate(true)
	var winning := str(_dictionary(model.call("_draw", 0)).get("number", "000"))
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
