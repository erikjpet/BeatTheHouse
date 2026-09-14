extends SceneTree

const RunStateScript := preload("res://scripts/core/run_state.gd")

var failures: Array[String] = []


func _init() -> void:
	_test_standard_backoff_and_persistence()
	_test_punchline_payback_is_once_only()
	if failures.is_empty():
		print("BLACKJACK_HEAT_BACKOFF_PROBE_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_standard_backoff_and_persistence() -> void:
	var run: RunState = _new_run("BLACKJACK-BACKOFF-STANDARD", "gas_station_casino", "Roadside Casino")
	# Result application is covered by the sealed-authority contract. This focused
	# probe begins at the documented threshold and verifies RunState's persistent
	# location-scoped consequence without forging an authority receipt.
	run.suspicion["level"] = RunStateScript.BLACKJACK_BACKOFF_HEAT
	var backoff := _apply_blackjack_backoff(run)
	var table := _blackjack_table(run)
	_check(run.suspicion_level() == RunStateScript.BLACKJACK_BACKOFF_HEAT, "Blackjack heat did not stop at the 90% backoff threshold.")
	_check(run.run_status == RunStateScript.RUN_STATUS_ACTIVE, "Blackjack backoff ended the run instead of leaving other games open.")
	_check(bool(table.get("barred", false)) and bool(table.get("heat_backoff", false)), "Blackjack table was not marked with a heat backoff.")
	_check(str(table.get("barred_scope", "")) == RunStateScript.BLACKJACK_BACKOFF_SCOPE, "Blackjack backoff did not use location scope.")
	_check(not bool((run.current_environment.get("game_states", {}) as Dictionary).get("roulette", {}).get("table_barred", false)), "Blackjack backoff barred another casino game.")
	_check(bool(backoff.get("triggered", false)), "RunState did not expose the blackjack backoff consequence.")

	var saved: Dictionary = run.to_dict()
	var restored := RunStateScript.new()
	restored.from_dict(saved)
	var restored_table := _blackjack_table(restored)
	_check(bool(restored_table.get("heat_backoff", false)) and bool(restored_table.get("barred", false)), "Blackjack location backoff did not survive save/load.")


func _test_punchline_payback_is_once_only() -> void:
	var run: RunState = _new_run("BLACKJACK-BACKOFF-PUNCHLINE", "small_underground_casino", "The Punchline")
	for member_id in ["crew_rook", "crew_velvet", "crew_knuckles", "crew_switch", "crew_mags", "crew_bishop", "crew_lucky"]:
		run.crew_add_trust(member_id, 60, "fixture")
	run.suspicion["level"] = RunStateScript.BLACKJACK_BACKOFF_HEAT
	var backoff := _apply_blackjack_backoff(run)
	for member_id in ["crew_rook", "crew_velvet", "crew_knuckles", "crew_switch", "crew_mags", "crew_bishop", "crew_lucky"]:
		_check(run.crew_trust(member_id) == 0, "Punchline backoff did not remove Crew standing for %s." % member_id)
	_check(_crew_favor_balance(run) == 1, "Punchline backoff did not add exactly one round of Crew favor debt.")
	_check(bool(backoff.get("crew_payback", false)), "Punchline backoff did not expose its Crew payback event.")
	_apply_blackjack_backoff(run)
	_check(_crew_favor_balance(run) == 1, "Repeated result application stacked Punchline backoff debt more than once.")


func _new_run(seed: String, archetype_id: String, display_name: String) -> RunState:
	var run: RunState = RunStateScript.new()
	run.start_new(seed)
	run.current_environment = {
		"id": "%s:fixture" % archetype_id,
		"world_node_id": archetype_id,
		"archetype_id": archetype_id,
		"display_name": display_name,
		"game_states": {
			"blackjack": {"dealer_name": "Mara", "hands_played": 3, "barred": false},
			"roulette": {"table_barred": false},
		},
	}
	return run


func _apply_blackjack_backoff(run: RunState) -> Dictionary:
	return run.apply_blackjack_heat_backoff({
		"game_id": "blackjack",
		"action_id": "play_basic",
	})


func _blackjack_table(run: RunState) -> Dictionary:
	var states: Dictionary = run.current_environment.get("game_states", {})
	var table: Variant = states.get("blackjack", {})
	return table as Dictionary if typeof(table) == TYPE_DICTIONARY else {}


func _crew_favor_balance(run: RunState) -> int:
	for value in run.debt:
		if typeof(value) == TYPE_DICTIONARY:
			var entry := value as Dictionary
			if str(entry.get("lender_id", "")) == RunStateScript.CREW_LENDER_ID and str(entry.get("debt_kind", "")) == "favor":
				return int(entry.get("balance", 0))
	return 0


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
