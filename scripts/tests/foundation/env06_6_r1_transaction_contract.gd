extends SceneTree

const RunStateScript := preload("res://scripts/core/run_state.gd")
const FAILURE_STAGES := [
	"preflight", "expiry", "global_start", "environment", "town_sweep",
	"encounter_and_rooms", "crew_and_world_models", "town_fact", "sweep_fact",
	"world_fact", "fact_flush", "legacy_expiry",
]


func _initialize() -> void:
	var failures: Array = []
	for stage in FAILURE_STAGES:
		_check_rejected_stage(str(stage), failures)
	_check_accepted_publish_rebind(failures)
	_check_active_room_alias_publish(failures)
	if failures.is_empty():
		print("env06_6 R1 detached turn transaction contract passed")
		quit(0)
		return
	for failure in failures: push_error(str(failure))
	quit(1)


func _fixture() -> Variant:
	var run: Variant = RunStateScript.new()
	run.start_new("ENV06-6-R1-TRANSACTION")
	run.current_environment = {
		"id": "r1_fixture_environment",
		"archetype_id": "motel",
		"world_node_id": "r1_fixture_node",
		"turns": 0,
		"suspicion": 0,
		"layout": {},
		"game_states": {
			"coin_pusher": {
				"settled_state": {
					"simulation": {
						"bodies": [
							{"id": 1, "x": 100, "nested": {"weight": 1}},
							{"id": 2, "x": 200, "nested": {"weight": 2}},
							{"id": 3, "x": 300, "nested": {"weight": 3}},
						],
					},
				},
			},
		},
	}
	run.world_map = {"nodes": [{"id": "r1_fixture_node", "environment": {"turns": 0}}]}
	run.grand_casino_room_states = {"lobby": {"turns": 0}}
	run.crew_jobs = {"job": {"status": "offered", "nested": {"turns": 0}}}
	run.scenario_host_transaction_ledger = {"receipts": {"before": true}, "queue": []}
	var shared := {"value": 7}
	run.narrative_flags["shared_probe"] = shared
	run.story_flags["shared_probe"] = shared
	run.narrative_flags["distinct_probe"] = {"value": 9}
	return run


func _check_rejected_stage(stage: String, failures: Array) -> void:
	var run: Variant = _fixture()
	var aliases := _aliases(run)
	var before := _alias_values(aliases)
	run._turn_transaction_test_failure_stage = stage
	var result: Dictionary = run.advance_environment_turns(1)
	if bool(result.get("ok", true)) or str(result.get("failure_stage", "")) != stage:
		failures.append("R1 forced stage %s did not reject at its exact boundary." % stage)
		return
	if not _same_alias_identities(run, aliases) or JSON.stringify(_alias_values(aliases)) != JSON.stringify(before):
		failures.append("R1 rejection after %s changed a retained identity or value." % stage)
	if not is_same(run.narrative_flags["shared_probe"], run.story_flags["shared_probe"]):
		failures.append("R1 rejection after %s broke shared-before alias topology." % stage)
	if is_same(run.narrative_flags["shared_probe"], run.narrative_flags["distinct_probe"]):
		failures.append("R1 rejection after %s collapsed distinct-before alias topology." % stage)


func _check_accepted_publish_rebind(failures: Array) -> void:
	var run: Variant = _fixture()
	var aliases := _aliases(run)
	var town_before: int = int(run.town_state.action_index)
	var numbers_before: int = int(run.numbers_state.action_index)
	var result: Dictionary = run.advance_environment_turns(1)
	if not bool(result.get("ok", false)) or not bool(result.get("applied", false)):
		failures.append("R1 valid detached candidate did not publish: %s" % JSON.stringify(result))
		return
	if not _same_alias_identities(run, aliases):
		failures.append("R1 accepted publish did not rebind through retained authoritative roots.")
	if int((aliases["environment"] as Dictionary).get("turns", 0)) != 1 \
			or run.town_state.action_index != town_before + 1 \
			or run.numbers_state.action_index != numbers_before + 1:
		failures.append("R1 accepted publish did not expose the complete environment/TownState/NumbersModel tuple: turns=%d town=%d/%d numbers=%d/%d." % [int((aliases["environment"] as Dictionary).get("turns", 0)), int(run.town_state.action_index), town_before + 1, int(run.numbers_state.action_index), numbers_before + 1])
	if not is_same(run.narrative_flags["shared_probe"], run.story_flags["shared_probe"]):
		failures.append("R1 accepted publish broke shared alias topology.")


func _check_active_room_alias_publish(failures: Array) -> void:
	var run: Variant = _fixture()
	run.grand_casino_room_states["active"] = run.current_environment
	var active_environment: Dictionary = run.current_environment
	var result: Dictionary = run.advance_environment_turns(1)
	if not bool(result.get("ok", false)) or not bool(result.get("applied", false)):
		failures.append("R1 active-room alias candidate did not publish: %s" % JSON.stringify(result))
		return
	if int(active_environment.get("turns", 0)) != 1:
		failures.append("R1 active-room alias overwrote the accepted environment turn during publish.")
	if not is_same(run.grand_casino_room_states.get("active", {}), active_environment):
		failures.append("R1 active-room alias was not retained after accepted publish.")


func _aliases(run: Variant) -> Dictionary:
	return {
		"town": run.town_state,
		"numbers": run.numbers_state,
		"environment": run.current_environment,
		"game_states": run.current_environment["game_states"],
		"world_map": run.world_map,
		"world_environment": run.world_map["nodes"][0]["environment"],
		"rooms": run.grand_casino_room_states,
		"crew_jobs": run.crew_jobs,
		"crew_job_nested": run.crew_jobs["job"]["nested"],
		"ledger": run.scenario_host_transaction_ledger,
		"receipts": run.scenario_host_transaction_ledger["receipts"],
	}


func _alias_values(aliases: Dictionary) -> Dictionary:
	return {
		"town": aliases["town"].snapshot(),
		"numbers": aliases["numbers"].snapshot(),
		"environment": (aliases["environment"] as Dictionary).duplicate(true),
		"game_states": (aliases["game_states"] as Dictionary).duplicate(true),
		"world_map": (aliases["world_map"] as Dictionary).duplicate(true),
		"rooms": (aliases["rooms"] as Dictionary).duplicate(true),
		"crew_jobs": (aliases["crew_jobs"] as Dictionary).duplicate(true),
		"ledger": (aliases["ledger"] as Dictionary).duplicate(true),
	}


func _same_alias_identities(run: Variant, aliases: Dictionary) -> bool:
	return is_same(run.town_state, aliases["town"]) \
		and is_same(run.numbers_state, aliases["numbers"]) \
		and is_same(run.current_environment, aliases["environment"]) \
		and is_same(run.current_environment.get("game_states", {}), aliases["game_states"]) \
		and is_same(run.world_map, aliases["world_map"]) \
		and is_same(run.world_map["nodes"][0]["environment"], aliases["world_environment"]) \
		and is_same(run.grand_casino_room_states, aliases["rooms"]) \
		and is_same(run.crew_jobs, aliases["crew_jobs"]) \
		and is_same(run.crew_jobs["job"]["nested"], aliases["crew_job_nested"]) \
		and is_same(run.scenario_host_transaction_ledger, aliases["ledger"]) \
		and is_same(run.scenario_host_transaction_ledger["receipts"], aliases["receipts"])
