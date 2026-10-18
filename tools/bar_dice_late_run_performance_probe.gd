extends SceneTree

# Measures the production Bar Dice sealed settlement with deliberately full,
# dense run histories. Preparation and fixture restoration are outside the timed
# window so the sample isolates the click-to-result authority boundary.

const MainScene := preload("res://scenes/main.tscn")
const SAMPLE_COUNT := 12
const MAX_P95_MS := 12.0

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.max_fps = 0
	root.size = Vector2i(1280, 720)
	var host: Control = MainScene.instantiate()
	host.set("show_game_library_launcher", true)
	host.set("continuous_environment_clock_enabled", false)
	host.set("autosave_slot_id", "bar_dice_late_run_performance_probe")
	root.add_child(host)
	await _settle(8)
	host.call("start_game_test_session", "bar_dice")
	await _settle(8)

	var run: RunState = host.get("run_state")
	var game: GameModule = host.get("current_game")
	if run == null or game == null or game.get_id() != "bar_dice":
		_fail("The production Bar Dice session did not open.")
		host.free()
		await _settle(2)
		_finish({})
		return
	if OS.get_environment("BTH_BAR_DICE_EMPTY_HISTORY") != "1":
		_fill_history(run)
	var base_snapshot := run.to_save_snapshot()
	var samples: Array[float] = []
	var result_chars := 0
	for sample_index in range(SAMPLE_COUNT):
		run.from_dict(base_snapshot)
		host.set("selected_stake", _selected_stake(game, run))
		var command := _prepare_roll(host, game, run)
		var delivery: Dictionary = command.get("_sealed_action_host_delivery", {}) if typeof(command.get("_sealed_action_host_delivery", {})) == TYPE_DICTIONARY else {}
		var prepared: Dictionary = command.get("_sealed_action_host_prepared", {}) if typeof(command.get("_sealed_action_host_prepared", {})) == TYPE_DICTIONARY else {}
		if delivery.is_empty():
			_fail("Sample %d did not prepare a sealed delivery." % sample_index)
			continue
		var started := Time.get_ticks_usec()
		var result: Dictionary = host.call("_sealed_action_host_resolve_intent", "roll", int(host.get("selected_stake")), delivery, prepared)
		samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
		if not bool(result.get("ok", false)):
			_fail("Sample %d failed settlement: %s" % [sample_index, str(result.get("message", "no message"))])
		result_chars = JSON.stringify(result).length()

	samples.sort()
	var avg_ms := 0.0
	for sample in samples:
		avg_ms += sample
	avg_ms /= float(maxi(1, samples.size()))
	var p95_ms := samples[clampi(int(ceil(float(samples.size()) * 0.95)) - 1, 0, maxi(0, samples.size() - 1))] if not samples.is_empty() else 0.0
	var max_ms := samples[-1] if not samples.is_empty() else 0.0
	if samples.size() != SAMPLE_COUNT:
		_fail("Only %d of %d samples completed." % [samples.size(), SAMPLE_COUNT])
	if p95_ms > MAX_P95_MS:
		_fail("Late-run Bar Dice settlement p95 %.3f ms exceeded %.3f ms." % [p95_ms, MAX_P95_MS])
	var metrics := {
		"sample_count": samples.size(),
		"avg_ms": avg_ms,
		"p95_ms": p95_ms,
		"max_ms": max_ms,
		"budget_p95_ms": MAX_P95_MS,
		"story_count": run.story_log.size(),
		"environment_history_count": run.environment_history.size(),
		"heat_history_count": run.heat_history.size(),
		"result_chars": result_chars,
	}
	host.free()
	await _settle(2)
	_finish(metrics)


func _selected_stake(game: GameModule, run: RunState) -> int:
	var state: Dictionary = game.call("_table_state_preview", run, run.current_environment)
	var ladder: Array = state.get("stake_ladder", []) if typeof(state.get("stake_ladder", [])) == TYPE_ARRAY else []
	return int(ladder[0]) if not ladder.is_empty() else 2


func _prepare_roll(host: Control, game: GameModule, run: RunState) -> Dictionary:
	var state: Dictionary = game.call("_table_state_preview", run, run.current_environment)
	var ladder: Array = state.get("stake_ladder", []) if typeof(state.get("stake_ladder", [])) == TYPE_ARRAY else []
	var stake := int(host.get("selected_stake"))
	var stake_index := 0
	for index in range(ladder.size()):
		if int(ladder[index]) == stake:
			stake_index = index
			break
	host.call("_sealed_action_host_surface_intent", "bar_dice_stake", stake_index, false, 1000)
	host.call("_sealed_action_host_surface_intent", "bar_dice_roll", 0, false, 1100)
	var command: Dictionary = host.call("_sealed_action_host_surface_intent", "bar_dice_ack_cover", 0, false, 1200)
	command = host.call("_sealed_action_host_surface_intent", "bar_dice_resolve", 0, false, 1300)
	command = host.call("_sealed_action_host_surface_intent", "bar_dice_throw", 0, false, 1600)
	command = host.call("_sealed_action_host_surface_intent", "bar_dice_reveal", 0, false, 1700)
	return host.call("_sealed_action_host_surface_intent", "bar_dice_ack_call", 0, false, 1800)


func _fill_history(run: RunState) -> void:
	var dense_payload := {
		"notes": "Late-run retained history payload used to detect whole-run copies.",
		"tags": ["bar", "casino", "travel", "dialogue", "crew", "economy"],
		"details": {"route": [1, 2, 3, 4, 5, 6], "flags": {"a": true, "b": false, "c": true}},
	}
	run.story_log = []
	for index in range(240):
		var row := dense_payload.duplicate(true)
		row["index"] = index
		row["message"] = "Historical story event %d" % index
		run.story_log.append(row)
	run.environment_history = []
	for index in range(256):
		var row := dense_payload.duplicate(true)
		row["id"] = "historical_room_%03d" % index
		row["entered_game_clock_minutes"] = index * 13
		run.environment_history.append(row)
	run.heat_history = []
	for index in range(480):
		var row := dense_payload.duplicate(true)
		row["level"] = index % 100
		row["game_clock_minutes"] = index * 3
		run.heat_history.append(row)
	run.grand_casino_atm_interest_notifications = []
	for index in range(32):
		run.grand_casino_atm_interest_notifications.append({"id": index, "payload": dense_payload.duplicate(true)})


func _settle(frame_count: int) -> void:
	for _index in range(frame_count):
		await process_frame


func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)


func _finish(metrics: Dictionary) -> void:
	print("BAR_DICE_LATE_RUN_PERFORMANCE_PROBE %s" % JSON.stringify({
		"passed": failures.is_empty(),
		"failures": failures,
		"metrics": metrics,
	}))
	quit(0 if failures.is_empty() else 1)
