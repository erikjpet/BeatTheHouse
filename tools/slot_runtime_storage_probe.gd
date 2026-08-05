extends SceneTree

# Release gate for slot runtime scheduling and v2 run storage. This exercises
# real generated cabinets and the production FoundationMain/SaveService paths;
# it does not substitute synthetic resolver timings for player-facing frames.

const MainScene := preload("res://scenes/main.tscn")
const SlotState := preload("res://scripts/games/slots/slot_machine_state.gd")
const COUNTS := [1, 3, 6, 12]
const IDLE_SAMPLES := 1000
const RUNTIME_ROUNDS := 12
const HANDOFF_SAMPLES := 8
const REPORT_PATH := "user://slot_runtime_storage_probe_report.json"
const SAVE_SLOT := "slot_runtime_storage_probe"

var app: Control
var failures: Array = []
var results: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	app = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", SAVE_SLOT)
	root.add_child(app)
	await process_frame
	await process_frame
	for count_value in COUNTS:
		var count := int(count_value)
		var keys := _install_room(count)
		var settled := _measure_settled_storage(keys)
		var idle := _measure_idle_scheduler(keys)
		var runtime := _measure_runtime(keys)
		var handoff := _measure_async_handoff()
		results.append({
			"fixture_count": count,
			"settled_storage": settled,
			"idle_scheduler": idle,
			"runtime": runtime,
			"async_handoff": handoff,
		})
		_apply_budgets(count, settled, idle, runtime, handoff)
	_finish()


func _install_room(fixture_count: int) -> Array:
	app.call("start_foundation_run", "SLOT-RUNTIME-STORAGE-%d" % fixture_count)
	var run_state: RunState = app.get("run_state")
	run_state.bankroll = 100000000
	var slot_game: GameModule = app.call("_game_module_for_id", "slot")
	var environment := {
		"id": "slot_runtime_storage_%d" % fixture_count,
		"archetype_id": "grand_casino",
		"display_name": "Slot Runtime Storage Gate",
		"kind": "casino",
		"tier": 3,
		"turns": 0,
		"game_ids": ["slot"],
		"event_ids": [],
		"resolved_event_ids": [],
		"item_offers": [],
		"service_ids": [],
		"lender_hooks": [],
		"travel_hooks": [],
		"next_archetypes": [],
		"object_fixtures": [],
		"layout": {"game_fixture_counts": {"slot": fixture_count}},
		"game_states": {},
	}
	environment["layout"] = EnvironmentInstance.ensure_generated_layout(environment)
	environment["game_states"] = slot_game.generate_environment_fixture_states(
		run_state, environment, run_state.create_rng("slot_runtime_storage_states"), fixture_count
	)
	run_state.set_environment(environment)
	app.set("current_game", null)
	app.call("_refresh_run_action_service")
	app.call("_set_current_screen", "ENVIRONMENT")
	app.call("_invalidate_environment_runtime_schedule", run_state.current_environment)
	var keys: Array = []
	for index in range(fixture_count):
		keys.append("slot" if index == 0 else "slot:%d" % (index + 1))
	return keys


func _measure_settled_storage(keys: Array) -> Dictionary:
	var run_state: RunState = app.get("run_state")
	# Representative capped late history uses the same compact routine receipt
	# shape as production slot actions and leaves the entry-count cap unchanged.
	for index in range(RunState.MAX_STORY_LOG_ENTRIES):
		run_state.log_story({
			"type": "game_action", "slot_event": "slot_spin", "game_id": "slot",
			"action_id": "spin", "family": "pinball" if index % 2 == 0 else "buffalo",
			"format_id": "classic_3_reel", "outcome_id": "zero_loss",
			"classification": "zero_loss", "stake_cost": 2,
			"bankroll_delta": -2, "environment_id": str(run_state.current_environment.get("id", "")),
		})
	var per_machine: Array = []
	var max_machine_bytes := 0
	for key_value in keys:
		var machine := SlotState.peek_machine(run_state.current_environment, str(key_value))
		var bytes := JSON.stringify(machine).length()
		var fields: Dictionary = {}
		for field_value in machine.keys():
			fields[str(field_value)] = JSON.stringify(machine.get(field_value)).length()
		per_machine.append({"state_key": str(key_value), "bytes": bytes, "fields": fields})
		max_machine_bytes = maxi(max_machine_bytes, bytes)
	var save_service: SaveService = app.get("save_service")
	var payload: Dictionary = save_service.call("_save_payload", run_state, SAVE_SLOT)
	var text: String = JSON.stringify(payload)
	return {
		"save_bytes": text.length(),
		"max_machine_bytes": max_machine_bytes,
		"per_machine": per_machine,
		"story_entries": run_state.story_log.size(),
		"contains_reel_strips": text.contains("\"reel_strips\"") or text.contains("\"bonus_reel_strips\""),
		"contains_completed_timeline": text.contains("\"slot_reel_timeline\"") or text.contains("\"slot_reel_stop_times\""),
	}


func _measure_idle_scheduler(keys: Array) -> Dictionary:
	var run_state: RunState = app.get("run_state")
	for key_value in keys:
		var machine := _runtime_machine(str(key_value))
		machine["slot_autoplay_active"] = true
		machine["slot_autoplay_next_msec"] = Time.get_ticks_msec() + 3600000
		_write_runtime_machine(str(key_value), machine)
	app.call("_invalidate_environment_runtime_schedule", run_state.current_environment)
	var samples: Array[float] = []
	for _index in range(IDLE_SAMPLES):
		app.call("_advance_environment_game_runtime")
		var timing: Dictionary = app.get("environment_runtime_last_timing_usec")
		samples.append(float(timing.get("schedule", 0)))
	samples.sort()
	var scheduler = app.get("environment_runtime_scheduler")
	return {
		"inspection_p95_usec": _percentile(samples, 0.95),
		"inspection_max_usec": samples.back() if not samples.is_empty() else 0.0,
		"scheduler": scheduler.debug_snapshot(str(run_state.current_environment.get("id", ""))),
	}


func _measure_runtime(keys: Array) -> Dictionary:
	var run_state: RunState = app.get("run_state")
	var samples: Array[float] = []
	var phase_samples := {"schedule": [], "resolve": [], "commit": [], "autosave_prepare": [], "total": []}
	var spins_before := _total_spins(keys)
	for _round in range(RUNTIME_ROUNDS):
		var active_count := 0
		for key_value in keys:
			var key := str(key_value)
			var machine := _runtime_machine(key)
			if SlotState.active_bonus_incomplete(machine):
				continue
			machine["slot_autoplay_active"] = true
			machine["slot_autoplay_next_msec"] = 1
			_write_runtime_machine(key, machine)
			active_count += 1
		for _index in range(active_count):
			var started := Time.get_ticks_usec()
			app.call("_advance_environment_game_runtime")
			samples.append(float(Time.get_ticks_usec() - started))
			var timing: Dictionary = app.get("environment_runtime_last_timing_usec")
			for phase_value in phase_samples.keys():
				(phase_samples[phase_value] as Array).append(float(timing.get(phase_value, 0)))
	samples.sort()
	var phase_p95_usec: Dictionary = {}
	for phase_value in phase_samples.keys():
		var phase_values: Array = phase_samples[phase_value]
		phase_values.sort()
		phase_p95_usec[phase_value] = _percentile(phase_values, 0.95)
	return {
		"samples": samples.size(),
		"resolved_spins": _total_spins(keys) - spins_before,
		"average_ms": _average(samples) / 1000.0,
		"p95_ms": _percentile(samples, 0.95) / 1000.0,
		"max_ms": (samples.back() if not samples.is_empty() else 0.0) / 1000.0,
		"phase_p95_usec": phase_p95_usec,
	}


func _measure_async_handoff() -> Dictionary:
	var run_state: RunState = app.get("run_state")
	var save_service: SaveService = app.get("save_service")
	if save_service.async_save_in_flight():
		save_service.wait_for_async_save()
	var samples: Array[float] = []
	var errors: Array = []
	for _index in range(HANDOFF_SAMPLES):
		var started := Time.get_ticks_usec()
		var error := save_service.begin_save_run(run_state, SAVE_SLOT)
		samples.append(float(Time.get_ticks_usec() - started))
		if error == OK:
			error = save_service.wait_for_async_save()
		if error != OK:
			errors.append(error)
	var parity_errors: Array = []
	var loaded_value: Variant = save_service.load_run(SAVE_SLOT)
	if not (loaded_value is RunState):
		parity_errors.append("latest async generation was not loadable")
	else:
		var loaded := loaded_value as RunState
		if loaded.seed_text != run_state.seed_text or loaded.rng_state != run_state.rng_state:
			parity_errors.append("seed/RNG state changed across v2 save/load")
		if loaded.bankroll != run_state.bankroll or _canonical_value(loaded.story_log) != _canonical_value(run_state.story_log):
			parity_errors.append("economy/story semantics changed across v2 save/load")
		var source_games: Variant = run_state.current_environment.get("game_states", {})
		var loaded_games: Variant = loaded.current_environment.get("game_states", {})
		if str(loaded.current_environment.get("id", "")) != str(run_state.current_environment.get("id", "")) or _canonical_value(loaded_games) != _canonical_value(source_games):
			parity_errors.append("environment/machine state changed across v2 save/load")
	samples.sort()
	return {
		"p95_ms": _percentile(samples, 0.95) / 1000.0,
		"max_ms": (samples.back() if not samples.is_empty() else 0.0) / 1000.0,
		"errors": errors,
		"load_parity_errors": parity_errors,
	}


func _runtime_machine(key: String) -> Dictionary:
	var run_state: RunState = app.get("run_state")
	var slot_game: GameModule = app.call("_game_module_for_id", "slot")
	var previous: Dictionary = run_state.current_environment.get("active_game_state_keys", {}).duplicate(true)
	var active := previous.duplicate(true)
	active["slot"] = key
	run_state.current_environment["active_game_state_keys"] = active
	var machine: Dictionary = slot_game.call("_read_machine", run_state.current_environment)
	run_state.current_environment["active_game_state_keys"] = previous
	return machine


func _write_runtime_machine(key: String, machine: Dictionary) -> void:
	var run_state: RunState = app.get("run_state")
	var slot_game: GameModule = app.call("_game_module_for_id", "slot")
	var previous: Dictionary = run_state.current_environment.get("active_game_state_keys", {}).duplicate(true)
	var active := previous.duplicate(true)
	active["slot"] = key
	run_state.current_environment["active_game_state_keys"] = active
	slot_game.call("_write_machine", run_state.current_environment, machine)
	run_state.current_environment["active_game_state_keys"] = previous


func _total_spins(keys: Array) -> int:
	var run_state: RunState = app.get("run_state")
	var total := 0
	for key_value in keys:
		total += int(SlotState.peek_machine(run_state.current_environment, str(key_value)).get("spin_count", 0))
	return total


func _apply_budgets(count: int, settled: Dictionary, idle: Dictionary, runtime: Dictionary, handoff: Dictionary) -> void:
	if float(runtime.get("p95_ms", 999.0)) > 16.6:
		failures.append("%d-cabinet runtime p95 exceeded 16.6 ms." % count)
	if float(idle.get("inspection_p95_usec", 999.0)) > 50.0:
		failures.append("%d-cabinet scheduler inspection p95 exceeded 50 usec." % count)
	if int(settled.get("max_machine_bytes", 999999)) > 4096:
		failures.append("%d-cabinet settled state exceeded 4 KB per cabinet." % count)
	if count == 12 and int(settled.get("save_bytes", 999999)) > 150000:
		failures.append("Twelve-cabinet capped-late-run v2 save exceeded 150 KB.")
	if bool(settled.get("contains_reel_strips", true)) or bool(settled.get("contains_completed_timeline", true)):
		failures.append("%d-cabinet v2 save retained definition/timeline duplication." % count)
	if count == 12 and (float(handoff.get("p95_ms", 999.0)) > 2.0 or float(handoff.get("max_ms", 999.0)) > 4.0):
		failures.append("Twelve-cabinet snapshot handoff exceeded 2/4 ms p95/max.")
	if not (handoff.get("errors", []) as Array).is_empty():
		failures.append("%d-cabinet async save returned errors." % count)
	if not (handoff.get("load_parity_errors", []) as Array).is_empty():
		failures.append("%d-cabinet v2 save/load semantic parity failed: %s" % [count, str(handoff.get("load_parity_errors", []))])


func _average(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())


func _percentile(values: Array, percentile: float) -> float:
	if values.is_empty():
		return 0.0
	return values[clampi(int(ceil(percentile * values.size())) - 1, 0, values.size() - 1)]


func _canonical_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var source: Dictionary = value
			var result: Dictionary = {}
			for key in source.keys():
				result[key] = _canonical_value(source[key])
			return result
		TYPE_ARRAY:
			var result_array: Array = []
			for entry in value as Array:
				result_array.append(_canonical_value(entry))
			return result_array
		TYPE_FLOAT:
			var number := float(value)
			var rounded: float = round(number)
			return int(rounded) if absf(number - rounded) <= 0.000000001 else snappedf(number, 0.000000001)
		TYPE_VECTOR2:
			var point: Vector2 = value
			return {"x": _canonical_value(point.x), "y": _canonical_value(point.y)}
		TYPE_VECTOR2I:
			var point_i: Vector2i = value
			return {"x": point_i.x, "y": point_i.y}
		_:
			return value


func _finish() -> void:
	var report := {"tool": "slot_runtime_storage_probe", "passed": failures.is_empty(), "failures": failures, "results": results}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report, "\t"))
	var save_service: SaveService = app.get("save_service")
	if save_service != null:
		save_service.clear_run(SAVE_SLOT)
	quit(0 if failures.is_empty() else 1)
