extends SceneTree

const ProfileInventoryScript := preload("res://scripts/core/profile_inventory.gd")

const WARMUP_COUNT := 12
const SAMPLE_COUNT := 180
const MAX_P95_MSEC := 0.65

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var payload := _profile_payload()
	var samples: Array[float] = []
	var restored: ProfileInventory
	for sample_index in range(WARMUP_COUNT + SAMPLE_COUNT):
		restored = ProfileInventoryScript.new()
		var started_usec := Time.get_ticks_usec()
		restored.from_dict(payload)
		var elapsed_usec := float(Time.get_ticks_usec() - started_usec)
		if sample_index >= WARMUP_COUNT:
			samples.append(elapsed_usec)

	_check(restored != null and restored.run_history.size() == ProfileInventoryScript.RUN_HISTORY_LIMIT, "Profile history did not retain its bounded entries.")
	_check(restored != null and restored.to_dict().get("future_profile_field", {}) == {"kept": true}, "Profile load did not preserve unknown forward-compatible fields.")
	_check((payload.get("run_history", []) as Array).size() == ProfileInventoryScript.RUN_HISTORY_LIMIT, "Profile normalization mutated its source history.")
	var compact_payload := restored.to_dict() if restored != null else {}
	var source_chars := JSON.stringify(payload).length()
	var compact_chars := JSON.stringify(compact_payload).length()
	for history_value in restored.run_history if restored != null else []:
		_check(typeof(history_value) == TYPE_DICTIONARY and not (history_value as Dictionary).has(ProfileInventoryScript.RELEASE_REPORTING_KEY), "Profile retained reporting-only details in recent-run history.")
	_check(compact_chars * 2 < source_chars, "Compacted profile history did not remove the redundant reporting payload.")

	var sorted := samples.duplicate()
	sorted.sort()
	var total_usec := 0.0
	for sample in samples:
		total_usec += sample
	var average_usec := total_usec / float(maxi(1, samples.size()))
	var p95_usec: float = float(sorted[clampi(int(ceil(float(sorted.size()) * 0.95)) - 1, 0, maxi(0, sorted.size() - 1))]) if not sorted.is_empty() else 0.0
	var max_usec: float = float(sorted[-1]) if not sorted.is_empty() else 0.0
	print("PROFILE_HISTORY_LOAD_METRICS samples=%d avg_ms=%.3f p95_ms=%.3f max_ms=%.3f source_chars=%d compact_chars=%d" % [samples.size(), average_usec / 1000.0, p95_usec / 1000.0, max_usec / 1000.0, source_chars, compact_chars])
	_check(p95_usec / 1000.0 <= MAX_P95_MSEC, "Profile history load p95 %.3f ms exceeded %.2f ms." % [p95_usec / 1000.0, MAX_P95_MSEC])

	if failures.is_empty():
		print("PROFILE_HISTORY_LOAD_PERFORMANCE_PROBE_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _profile_payload() -> Dictionary:
	var history: Array = []
	for index in range(ProfileInventoryScript.RUN_HISTORY_LIMIT):
		history.append({
			"seed": "PROFILE-HISTORY-%d" % index,
			"route": "players_card_cashout",
			"outcome": "victory" if index % 2 == 0 else "failure",
			"failure_reason": "" if index % 2 == 0 else "bankroll_zero",
			"final_bankroll": 200 + index,
			"day_count": 2,
			"duration_actions": 120 + index,
			"completed_date": "2026-09-%02d" % (index + 1),
			"completed_unix": 1800000000 + index,
			"score": 1000 + index,
			"games_played": {"slot": 20, "blackjack": 12, "video_poker": 18},
			"release_0_6": {
				"crew": {"members_met": _report_rows("crew", 12), "jobs_completed": 8},
				"world": {"scenarios": _report_rows("scenario", 24), "notable_outcomes": _report_rows("outcome", 16)},
				"numbers": {"slips_placed": 10, "hits": 2},
				"deliveries": {"runs_completed": 6, "packages_lost": 1},
			},
		})
	return {
		"schema_version": ProfileInventoryScript.SCHEMA_VERSION,
		"items": [],
		"challenge_completions": {},
		"run_history": history,
		"daily_runs": {},
		"lifetime_stats": {},
		"tips_seen": {},
		"tutorial_completed": true,
		"future_profile_field": {"kept": true},
	}


func _report_rows(prefix: String, count: int) -> Array:
	var rows: Array = []
	for index in range(count):
		rows.append({"id": "%s_%d" % [prefix, index], "label": "Retained history row %d" % index, "value": index})
	return rows


func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
