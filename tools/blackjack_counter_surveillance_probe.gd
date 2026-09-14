extends SceneTree

const BlackjackScript := preload("res://scripts/games/blackjack.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: BlackjackGame = BlackjackScript.new()
	var contract := game.sealed_action_authority_contract()
	_check((contract.get("skip_environment_turn_actions", []) as Array).has("count_cards"), "Recording a count was not declared part of the current hand's existing environment turn.")
	_test_flat_accurate_play(game)
	_test_count_shaped_bet_ramp(game)
	_test_count_error_cadence(game)
	_test_bounded_history(game)
	game = null
	if failures.is_empty():
		print("BLACKJACK_COUNTER_SURVEILLANCE_PROBE_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_flat_accurate_play(game: BlackjackGame) -> void:
	var table := _table()
	var counts := [-3, -2, -1, 0, 1, 2, 3, 4, 2, 0, -2, 1, 3, 0, -1, 2]
	var total_heat := 0
	for count_value in counts:
		table["running_count"] = count_value
		var assessment: Dictionary = game.call("_counter_surveillance_for_hand", _count_session(true, 0), table, 5)
		total_heat += int(assessment.get("heat", -1))
		if int(assessment.get("catch_chance", -1)) != 0:
			failures.append("Flat-bet accurate counting generated a catch chance on count %+d." % count_value)
		game.call("_persist_counter_surveillance", table, {"counter_surveillance": assessment})
	_check(total_heat == 0, "Sixteen accurate flat-bet hands generated %d Heat instead of remaining observationally invisible." % total_heat)
	_check(int(table.get("counter_observation_hands", 0)) == counts.size(), "Flat-bet surveillance did not retain the multi-hand sample count.")
	_check(int(table.get("counter_evidence_points", -1)) == 0, "Flat-bet accurate counting accumulated counter evidence.")


func _test_count_shaped_bet_ramp(game: BlackjackGame) -> void:
	var table := _table()
	var counts := [-2, -1, 0, 1, 2, 3, 4, 5]
	var bets := [5, 5, 5, 5, 10, 20, 30, 40]
	var early_heat := 0
	var ramp_heat := 0
	var last_assessment: Dictionary = {}
	for index in range(counts.size()):
		table["running_count"] = counts[index]
		last_assessment = game.call("_counter_surveillance_for_hand", _count_session(true, 0), table, bets[index])
		if index < 4:
			early_heat += int(last_assessment.get("heat", 0))
		else:
			ramp_heat += int(last_assessment.get("heat", 0))
		game.call("_persist_counter_surveillance", table, {"counter_surveillance": last_assessment})
	_check(early_heat == 0, "Ordinary opening wagers generated Heat before any count-shaped bet movement.")
	_check(ramp_heat >= 6, "A sustained positive-count wager ramp did not generate meaningful surveillance Heat.")
	_check(float(last_assessment.get("correlation", 0.0)) >= 0.70, "Count-shaped wagers did not produce the expected strong rolling correlation.")
	_check(int(last_assessment.get("catch_chance", 0)) > 0, "A mature count/bet pattern never became eligible for surveillance detection.")
	_check(bool(last_assessment.get("significant_pattern", false)), "A mature count/bet pattern was not marked significant.")


func _test_count_error_cadence(game: BlackjackGame) -> void:
	var table := _table()
	table["running_count"] = 1
	var first: Dictionary = game.call("_counter_surveillance_for_hand", _count_session(false, 1), table, 5)
	game.call("_persist_counter_surveillance", table, {"counter_surveillance": first})
	var second: Dictionary = game.call("_counter_surveillance_for_hand", _count_session(false, 2), table, 5)
	_check(int(first.get("heat", 0)) == 1, "One missed count pulse caused more than a minor attention tick.")
	_check(int(first.get("catch_chance", -1)) == 0, "One missed pulse immediately exposed the player as a counter.")
	_check(int(second.get("heat", 0)) >= 4, "Repeated/multiple count misses did not generate significant Heat.")
	_check(int(second.get("heat", 99)) <= BlackjackGame.COUNTER_SURVEILLANCE_MAX_MISS_HEAT, "Count-error Heat exceeded its per-hand cap.")
	_check(bool(second.get("significant_pattern", false)), "Repeated count misses were not marked as a meaningful attention pattern.")


func _test_bounded_history(game: BlackjackGame) -> void:
	var table := _table()
	for index in range(80):
		table["running_count"] = (index % 9) - 4
		var assessment: Dictionary = game.call("_counter_surveillance_for_hand", _count_session(true, 0), table, 5)
		game.call("_persist_counter_surveillance", table, {"counter_surveillance": assessment})
	var samples: Array = table.get("counter_observation_samples", [])
	_check(samples.size() == BlackjackGame.COUNTER_SURVEILLANCE_SAMPLE_LIMIT, "Counter surveillance history grew beyond its fixed rolling window.")
	_check(int(table.get("counter_observation_hands", 0)) == 80, "Bounded history lost the total observed-hand count.")


func _table() -> Dictionary:
	return {
		"running_count": 0,
		"counter_observation_hands": 0,
		"counter_observation_samples": [],
		"counter_evidence_points": 0,
		"counter_miss_streak": 0,
	}


func _count_session(correct: bool, error_units: int) -> Dictionary:
	var missed: Array = []
	for index in range(error_units):
		missed.append("miss_%d" % index)
	return {
		"count_answered": true,
		"count_attempted": true,
		"count_correct": correct,
		"count_delta": 0,
		"cheats_used": {"count_cards": true},
		"count_challenge": {
			"target_delta": 0,
			"recorded_delta": 0,
			"missed_icons": missed,
			"bad_hits": 0,
		},
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
