extends SceneTree

const RunStateScript := preload("res://scripts/core/run_state.gd")

const WARMUP_COUNT := 8
const SAMPLE_COUNT := 80
const MAX_P95_MSEC := 2.5

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var run: RunState = RunStateScript.new()
	run.start_new("RUN-HISTORY-TRANSACTION-PERFORMANCE")
	run.current_environment = {
		"id": "history_perf_room",
		"archetype_id": "bar",
		"world_node_id": "history_perf_room",
		"display_name": "History Performance Room",
		"visual_context": {},
		"travel_lock_remaining": 0,
		"economic_profile": {},
		"game_states": {},
	}
	_fill_history(run)

	var samples: Array[float] = []
	for sample_index in range(WARMUP_COUNT + SAMPLE_COUNT):
		var started_usec := Time.get_ticks_usec()
		var candidate := run.detached_host_action_candidate()
		if candidate == null:
			_fail("Shared host transaction did not produce a candidate.")
			break
		# Exercise the accepted-action publish boundary too. No history entry is
		# changed, so this measures only redundant isolation/reconciliation work.
		if not run.publish_host_action_candidate(candidate):
			_fail("Shared host transaction candidate could not be published.")
			break
		var elapsed_usec := float(Time.get_ticks_usec() - started_usec)
		if sample_index >= WARMUP_COUNT:
			samples.append(elapsed_usec)

	_check(run.story_log.size() == RunStateScript.MAX_STORY_LOG_ENTRIES, "Transaction changed retained story history.")
	_check(run.environment_history.size() == RunStateScript.MAX_ENVIRONMENT_HISTORY_ENTRIES, "Transaction changed retained environment history.")
	_check(run.heat_history.size() == RunStateScript.MAX_HEAT_HISTORY_ENTRIES, "Transaction changed retained heat history.")
	_check(run.grand_casino_atm_interest_notifications.size() == RunStateScript.MAX_ATM_INTEREST_NOTIFICATIONS, "Transaction changed retained notification history.")

	# Append and clear operations must remain isolated even though old entries can
	# be shared as immutable values between the live run and a transaction view.
	var isolation_candidate := run.detached_host_action_candidate()
	var live_story_size := run.story_log.size()
	isolation_candidate.log_story({"type": "fixture_append", "message": "candidate only"})
	_check(run.story_log.size() == live_story_size, "Candidate story append leaked into the live run.")
	isolation_candidate.grand_casino_atm_interest_notifications.clear()
	_check(run.grand_casino_atm_interest_notifications.size() == RunStateScript.MAX_ATM_INTEREST_NOTIFICATIONS, "Candidate notification clear leaked into the live run.")

	var sorted := samples.duplicate()
	sorted.sort()
	var average_usec := 0.0
	for sample in samples:
		average_usec += sample
	average_usec = average_usec / float(maxi(1, samples.size()))
	var p95_usec: float = float(sorted[clampi(int(ceil(float(sorted.size()) * 0.95)) - 1, 0, maxi(0, sorted.size() - 1))]) if not sorted.is_empty() else 0.0
	var max_usec: float = float(sorted[-1]) if not sorted.is_empty() else 0.0
	print("RUN_HISTORY_TRANSACTION_METRICS samples=%d avg_ms=%.3f p95_ms=%.3f max_ms=%.3f" % [samples.size(), average_usec / 1000.0, p95_usec / 1000.0, max_usec / 1000.0])
	_check(p95_usec / 1000.0 <= MAX_P95_MSEC, "Late-run transaction p95 %.3f ms exceeded %.1f ms." % [p95_usec / 1000.0, MAX_P95_MSEC])

	if failures.is_empty():
		print("RUN_HISTORY_TRANSACTION_PERFORMANCE_PROBE_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _fill_history(run: RunState) -> void:
	run.story_log.clear()
	run.environment_history.clear()
	run.heat_history.clear()
	run.grand_casino_atm_interest_notifications.clear()
	var detail := {
		"message": "A retained late-run record that normal play does not mutate.",
		"tags": ["casino", "history", "performance", "transaction"],
		"payload": {"values": range(24), "nested": {"a": 1, "b": 2, "c": 3}},
	}
	for index in range(RunStateScript.MAX_STORY_LOG_ENTRIES):
		var entry := detail.duplicate(true)
		entry["type"] = "fixture_story"
		entry["index"] = index
		run.story_log.append(entry)
	for index in range(RunStateScript.MAX_ENVIRONMENT_HISTORY_ENTRIES):
		var entry := detail.duplicate(true)
		entry["id"] = "room_%d" % index
		entry["turns"] = index
		run.environment_history.append(entry)
	for index in range(RunStateScript.MAX_HEAT_HISTORY_ENTRIES):
		run.heat_history.append({
			"action_index": index,
			"game_clock_minutes": index,
			"heat_value": index % 101,
			"environment_id": "room_%d" % (index % 12),
			"world_node_id": "node_%d" % (index % 12),
			"environment_name": "Fixture Room",
			"transition": index % 20 == 0,
		})
	for index in range(RunStateScript.MAX_ATM_INTEREST_NOTIFICATIONS):
		run.grand_casino_atm_interest_notifications.append({
			"boundary_index": index,
			"old_balance": 100 + index,
			"new_balance": 105 + index,
			"message": "Fixture interest boundary %d" % index,
		})


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	if not failures.has(message):
		failures.append(message)
