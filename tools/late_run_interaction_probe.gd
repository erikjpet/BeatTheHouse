extends SceneTree

# Read-only acceptance probe for the largest persisted run fixture. It catches
# regressions where routine UI refreshes or route scouting scale with historical
# receipts, visited room payloads, or the complete map.

const MainScene := preload("res://scenes/main.tscn")
const FIXTURE_SLOT := "pathological_continue_save_probe_copy"
const MAX_WARM_FULL_REFRESH_AVG_MS := 100.0
const MAX_SELECTED_SCOUT_PREVIEW_AVG_MS := 40.0


func _init() -> void:
	call_deferred("_run")


func _average_ms(callable: Callable, iterations: int) -> float:
	var started := Time.get_ticks_usec()
	for _index in range(iterations):
		callable.call()
	return (float(Time.get_ticks_usec() - started) / 1000.0) / float(maxi(1, iterations))


func _run() -> void:
	var failures: Array = []
	var host = MainScene.instantiate()
	# Configure the fixture before _ready so this probe never observes or writes
	# the player's Continue slot. Practice mode disables every autosave mutation.
	host.autosave_slot_id = FIXTURE_SLOT
	host.dev_game_test_mode = true
	root.add_child(host)
	await process_frame
	host.load_foundation_run()
	host.pending_autosave = false
	if host.run_state == null:
		failures.append("Pathological late-run fixture could not be loaded.")
	else:
		host._refresh()
		var warm_refresh_avg_ms := _average_ms(func(): host._refresh(), 8)
		var target_ids: Array = host._travel_target_ids()
		var selected_scout_avg_ms := 0.0
		if not target_ids.is_empty():
			host.selected_travel_target_id = str(target_ids[0])
			host._invalidate_travel_view_cache()
			selected_scout_avg_ms = _average_ms(func(): host._travel_choice_view_list(), 4)
		if warm_refresh_avg_ms > MAX_WARM_FULL_REFRESH_AVG_MS:
			failures.append("Warm late-run refresh averaged %.1f ms (limit %.1f ms)." % [warm_refresh_avg_ms, MAX_WARM_FULL_REFRESH_AVG_MS])
		if selected_scout_avg_ms > MAX_SELECTED_SCOUT_PREVIEW_AVG_MS:
			failures.append("Selected late-run scout preview averaged %.1f ms (limit %.1f ms)." % [selected_scout_avg_ms, MAX_SELECTED_SCOUT_PREVIEW_AVG_MS])
		print("LATE_RUN_INTERACTION_PROBE refresh_avg_ms=%.3f selected_scout_avg_ms=%.3f save_chars=%d story=%d heat=%d failures=%d" % [
			warm_refresh_avg_ms,
			selected_scout_avg_ms,
			JSON.stringify(host.run_state.to_save_snapshot()).length(),
			host.run_state.story_log.size(),
			host.run_state.heat_history.size(),
			failures.size(),
		])
	host.queue_free()
	for failure in failures:
		push_error(str(failure))
	quit(1 if not failures.is_empty() else 0)
