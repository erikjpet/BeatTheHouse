extends SceneTree

# Sustained foreground-autoplay regression gate. The older slot probes measured
# either renderer-only frames or offscreen resolution, so they could stay green
# while the sealed foreground transaction grew more expensive after each cached
# response. This fixture keeps a late-run story ledger, exercises the production
# FoundationMain autoplay path, and checks both action latency and presentation
# handoff continuity.

const MainScene := preload("res://scenes/main.tscn")
const SlotState := preload("res://scripts/games/slots/slot_machine_state.gd")
const ActionAuthority := preload("res://scripts/core/blackjack_action_authority.gd")
const SAVE_SLOT := "slot_foreground_autoplay_performance_probe"
const SAMPLE_COUNT := 16
const WARMUP_COUNT := 2
const MAX_ACTION_P95_MS := 22.0
const MAX_ACTION_MS := 30.0
const MAX_NEXT_FRAME_P95_MS := 20.0
const MAX_DRAW_P95_MS := 4.0
const MAX_BACKGROUND_DRAIN_P95_MS := 8.0
const MAX_TAIL_TO_HEAD_RATIO := 1.5
const MAX_CACHED_RESPONSES := 2
const FIXTURE_COUNT := 6
const FOREGROUND_STATE_KEY := "slot:6"

var app: Control
var failures: Array = []
var action_samples_usec: Array[float] = []
var prepare_samples_usec: Array[float] = []
var resolve_samples_usec: Array[float] = []
var frame_samples_usec: Array[float] = []
var background_frame_samples_usec: Array[float] = []
var background_drain_frame_samples_usec: Array[float] = []
var spin_ids: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	app = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", SAVE_SLOT)
	root.add_child(app)
	await _settle(3)
	var practice_result: Dictionary = app.call("start_game_test_session", "slot")
	if not bool(practice_result.get("ok", false)):
		_fail("Could not start the six-cabinet Slot practice room.")
		_finish()
		return
	await _settle(3)
	var run_state: RunState = app.get("run_state")
	run_state.bankroll = 1000000
	var fixture_identities := _fixture_identities(run_state)
	var expected_identities := [
		"pinball:classic_3_reel", "buffalo:line_5x3", "pinball:video_feature",
		"buffalo:classic_3_reel", "pinball:line_5x3", "buffalo:video_feature",
	]
	if fixture_identities != expected_identities:
		_fail("Six-cabinet fixture did not contain every authored Slot identity: %s." % JSON.stringify(fixture_identities))
		_finish()
		return
	# Reproduce the late-run cost that was hidden by the short renderer probe.
	for index in range(RunState.MAX_STORY_LOG_ENTRIES):
		run_state.log_story({
			"type": "game_action",
			"game_id": "slot",
			"action_id": "spin",
			"slot_event": "slot_spin",
			"classification": "zero_loss",
			"stake_cost": 2,
			"environment_id": str(run_state.current_environment.get("id", "practice_slot")),
			"sample": index,
		})
	app.call("_refresh_run_action_service")
	app.call("_refresh")
	if not bool(app.call("enter_game", "slot", FOREGROUND_STATE_KEY)):
		_fail("Could not enter the foreground slot fixture.")
		_finish()
		return
	await _settle(4)
	var canvas: Control = app.get("game_surface_canvas") as Control
	if canvas == null:
		_fail("Foreground slot canvas was unavailable.")
		_finish()
		return
	var initial_fallbacks := int(app.get("embedded_full_snapshot_fallback_count"))
	var initial_incremental := int(app.get("embedded_incremental_snapshot_count"))
	canvas.call("reset_performance_counters")
	for sample_index in range(SAMPLE_COUNT + WARMUP_COUNT):
		_arm_next_ordinary_autoplay_spin(run_state, FOREGROUND_STATE_KEY)
		for state_key in _background_state_keys():
			_arm_background_ordinary_autoplay_spin(run_state, state_key)
		app.call("_invalidate_environment_runtime_schedule", run_state.current_environment)
		var background_spins_before := _background_spin_count(run_state)
		var before_machine := SlotState.peek_machine(run_state.current_environment, FOREGROUND_STATE_KEY)
		var before_count := int(before_machine.get("spin_count", 0))
		var action_started_usec := Time.get_ticks_usec()
		var surface_time_msec := int(app.call("_environment_simulation_time_msec"))
		var authority_ui_state: Dictionary = app.call("_current_game_surface_auto_tick_state")
		var prepare_started_usec := Time.get_ticks_usec()
		var authority_command: Dictionary = app.call("_sealed_action_host_auto_intent", surface_time_msec)
		var prepare_usec := Time.get_ticks_usec() - prepare_started_usec
		var resolve_started_usec := Time.get_ticks_usec()
		app.call("_apply_game_surface_automation_command", authority_command, authority_ui_state)
		var resolve_usec := Time.get_ticks_usec() - resolve_started_usec
		var action_usec := Time.get_ticks_usec() - action_started_usec
		var after_machine := SlotState.peek_machine(run_state.current_environment, FOREGROUND_STATE_KEY)
		var after_count := int(after_machine.get("spin_count", 0))
		if after_count != before_count + 1:
			_fail("Autoplay sample %d advanced spin count %d -> %d." % [sample_index, before_count, after_count])
			break
		var animation_id := str(after_machine.get("slot_animation_id", ""))
		if animation_id.is_empty():
			_fail("Autoplay sample %d produced no reel animation id." % sample_index)
			break
		# Prevent the intentionally forced next-due timestamp from creating a second
		# automatic action while the probe yields. The measured action above still
		# crossed the exact production autoplay path with autoplay enabled.
		var paused_machine := SlotState.read_machine(run_state.current_environment, FOREGROUND_STATE_KEY)
		paused_machine["slot_autoplay_active"] = false
		paused_machine["slot_autoplay_next_msec"] = 0
		SlotState.write_runtime_machine(run_state.current_environment, FOREGROUND_STATE_KEY, paused_machine)
		var frame_started_usec := Time.get_ticks_usec()
		await process_frame
		var frame_usec := Time.get_ticks_usec() - frame_started_usec
		var sample_background_frames: Array[float] = []
		for _frame_index in range(5):
			frame_started_usec = Time.get_ticks_usec()
			await process_frame
			sample_background_frames.append(float(Time.get_ticks_usec() - frame_started_usec))
		var background_spins_after := _background_spin_count(run_state)
		if background_spins_after != background_spins_before:
			_fail("Autoplay sample %d advanced %d background spins during the visible reel animation." % [sample_index, background_spins_after - background_spins_before])
			break
		var sample_drain_frames: Array[float] = []
		# The scheduler deliberately leaves one quiet frame between background
		# settlements, so five overdue cabinets need at most ten service passes.
		for _frame_index in range(FIXTURE_COUNT * 2):
			canvas.set("surface_animation_channels", {})
			canvas.set("surface_animation_handoff_until_msec", 0)
			frame_started_usec = Time.get_ticks_usec()
			app.call("_advance_environment_game_runtime")
			sample_drain_frames.append(float(Time.get_ticks_usec() - frame_started_usec))
		background_spins_after = _background_spin_count(run_state)
		if background_spins_after != background_spins_before + FIXTURE_COUNT - 1:
			_fail("Autoplay sample %d did not drain all five deferred background spins; got %d." % [sample_index, background_spins_after - background_spins_before])
			break
		var rendered: Dictionary = canvas.call("realtime_surface_state")
		if str(rendered.get("slot_animation_id", "")) != animation_id:
			_fail("Autoplay sample %d did not hand the resolved animation to the canvas." % sample_index)
			break
		if sample_index >= WARMUP_COUNT:
			action_samples_usec.append(float(action_usec))
			prepare_samples_usec.append(float(prepare_usec))
			resolve_samples_usec.append(float(resolve_usec))
			frame_samples_usec.append(float(frame_usec))
			background_frame_samples_usec.append_array(sample_background_frames)
			background_drain_frame_samples_usec.append_array(sample_drain_frames)
			spin_ids.append(animation_id)
	var machine := SlotState.peek_machine(run_state.current_environment, FOREGROUND_STATE_KEY)
	var ledger: Dictionary = machine.get("_blackjack_action_authority", {}) if typeof(machine.get("_blackjack_action_authority", {})) == TYPE_DICTIONARY else {}
	var cache_count := (ledger.get("request_order", []) as Array).size() if typeof(ledger.get("request_order", [])) == TYPE_ARRAY else -1
	var action_stats := _stats(action_samples_usec)
	var frame_stats := _stats(frame_samples_usec)
	var head_avg := _average(action_samples_usec.slice(0, mini(4, action_samples_usec.size()))) / 1000.0
	var tail_avg := _average(action_samples_usec.slice(maxi(0, action_samples_usec.size() - 4), action_samples_usec.size())) / 1000.0
	var tail_ratio := tail_avg / maxf(0.001, head_avg)
	var fallback_delta := int(app.get("embedded_full_snapshot_fallback_count")) - initial_fallbacks
	var incremental_delta := int(app.get("embedded_incremental_snapshot_count")) - initial_incremental
	var authority_profile := _authority_profile(run_state, machine, ledger)
	var canvas_performance: Dictionary = canvas.call("performance_counters")
	var background_drain_stats := _stats(background_drain_frame_samples_usec)
	if float(action_stats.get("p95_ms", 999.0)) > MAX_ACTION_P95_MS:
		_fail("Foreground autoplay action p95 %.3f ms exceeded %.3f ms." % [float(action_stats.get("p95_ms", 0.0)), MAX_ACTION_P95_MS])
	if float(action_stats.get("max_ms", 999.0)) > MAX_ACTION_MS:
		_fail("Foreground autoplay action max %.3f ms exceeded %.3f ms." % [float(action_stats.get("max_ms", 0.0)), MAX_ACTION_MS])
	if float(frame_stats.get("p95_ms", 999.0)) > MAX_NEXT_FRAME_P95_MS:
		_fail("Foreground autoplay next-frame p95 %.3f ms exceeded %.3f ms." % [float(frame_stats.get("p95_ms", 0.0)), MAX_NEXT_FRAME_P95_MS])
	if float(canvas_performance.get("draw_p95_ms", 999.0)) > MAX_DRAW_P95_MS:
		_fail("Six-type Slot draw p95 %.3f ms exceeded %.3f ms." % [float(canvas_performance.get("draw_p95_ms", 0.0)), MAX_DRAW_P95_MS])
	if float(background_drain_stats.get("p95_ms", 999.0)) > MAX_BACKGROUND_DRAIN_P95_MS:
		_fail("Five-cabinet drain p95 %.3f ms exceeded %.3f ms." % [float(background_drain_stats.get("p95_ms", 0.0)), MAX_BACKGROUND_DRAIN_P95_MS])
	if tail_ratio > MAX_TAIL_TO_HEAD_RATIO:
		_fail("Foreground autoplay tail/head ratio %.3fx exceeded %.3fx." % [tail_ratio, MAX_TAIL_TO_HEAD_RATIO])
	if cache_count < 0 or cache_count > MAX_CACHED_RESPONSES:
		_fail("Foreground slot retained %d sealed replay responses; expected at most %d." % [cache_count, MAX_CACHED_RESPONSES])
	if _unique_count(spin_ids) != action_samples_usec.size():
		_fail("Foreground autoplay reused an animation id across measured spins (%d unique for %d spins)." % [_unique_count(spin_ids), action_samples_usec.size()])
	if fallback_delta > 0 or incremental_delta != action_samples_usec.size() + WARMUP_COUNT:
		_fail("Foreground slot refreshes were not wholly incremental (fallback=%d incremental=%d)." % [fallback_delta, incremental_delta])
	print(JSON.stringify({
		"tool": "slot_foreground_autoplay_performance_probe",
		"passed": failures.is_empty(),
		"failures": failures,
		"samples": action_samples_usec.size(),
		"action": action_stats,
		"prepare": _stats(prepare_samples_usec),
		"resolve": _stats(resolve_samples_usec),
		"next_frame": frame_stats,
		"background_frames": _stats(background_frame_samples_usec),
		"background_drain_frames": background_drain_stats,
		"fixture_identities": fixture_identities,
		"head_avg_ms": head_avg,
		"tail_avg_ms": tail_avg,
		"tail_to_head_ratio": tail_ratio,
		"cached_responses": cache_count,
		"full_snapshot_fallbacks": fallback_delta,
		"incremental_snapshot_refreshes": incremental_delta,
		"unique_animation_ids": _unique_count(spin_ids),
		"action_samples_ms": _milliseconds(action_samples_usec),
		"authority_profile": authority_profile,
		"canvas_performance": canvas_performance,
	}, "\t"))
	_finish()


func _arm_next_ordinary_autoplay_spin(run_state: RunState, state_key: String) -> void:
	var machine := SlotState.read_machine(run_state.current_environment, state_key)
	# A feature is valid gameplay but would turn this into a pinball/bonus timing
	# probe. Keep the fixture on the ordinary reel path while retaining its sealed
	# authority ledger and accumulated spin counters.
	var active: Dictionary = machine.get("active_bonus", {}) if typeof(machine.get("active_bonus", {})) == TYPE_DICTIONARY else {}
	if bool(active.get("active", false)) and not bool(active.get("complete", false)):
		machine["active_bonus"] = {"active": false, "complete": true}
		machine["last_bonus_complete"] = true
		machine["slot_bonus_trigger_revealed"] = true
		machine.erase("slot_bonus_auto_next_msec")
		machine.erase("slot_bonus_watchdog_since_msec")
	machine["slot_autoplay_active"] = true
	machine["slot_autoplay_next_msec"] = 1
	SlotState.write_runtime_machine(run_state.current_environment, state_key, machine)


func _arm_background_ordinary_autoplay_spin(run_state: RunState, state_key: String) -> void:
	_arm_next_ordinary_autoplay_spin(run_state, state_key)


func _background_spin_count(run_state: RunState) -> int:
	var total := 0
	for state_key in _background_state_keys():
		total += int(SlotState.peek_machine(run_state.current_environment, state_key).get("spin_count", 0))
	return total


func _background_state_keys() -> Array[String]:
	var keys: Array[String] = []
	for fixture_index in range(FIXTURE_COUNT):
		var state_key := "slot" if fixture_index == 0 else "slot:%d" % (fixture_index + 1)
		if state_key != FOREGROUND_STATE_KEY:
			keys.append(state_key)
	return keys


func _fixture_identities(run_state: RunState) -> Array:
	var identities: Array = []
	for fixture_index in range(FIXTURE_COUNT):
		var state_key := "slot" if fixture_index == 0 else "slot:%d" % (fixture_index + 1)
		var machine := SlotState.peek_machine(run_state.current_environment, state_key)
		identities.append("%s:%s" % [str(machine.get("type_id", "")), str(machine.get("format_id", ""))])
	return identities


func _stats(samples_usec: Array[float]) -> Dictionary:
	if samples_usec.is_empty():
		return {"avg_ms": 0.0, "p95_ms": 0.0, "max_ms": 0.0}
	var sorted := samples_usec.duplicate()
	sorted.sort()
	return {
		"avg_ms": _average(samples_usec) / 1000.0,
		"p95_ms": float(sorted[clampi(int(ceil(float(sorted.size()) * 0.95)) - 1, 0, sorted.size() - 1)]) / 1000.0,
		"max_ms": float(sorted.back()) / 1000.0,
	}


func _average(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += float(value)
	return total / float(values.size())


func _unique_count(values: Array[String]) -> int:
	var unique := {}
	for value in values:
		unique[value] = true
	return unique.size()


func _milliseconds(values: Array[float]) -> Array:
	var result: Array = []
	for value in values:
		result.append(snappedf(float(value) / 1000.0, 0.001))
	return result


func _authority_profile(run_state: RunState, machine: Dictionary, ledger: Dictionary) -> Dictionary:
	var validation_samples: Array[float] = []
	var response_fingerprint_samples: Array[float] = []
	var candidate_detach_samples: Array[float] = []
	var candidate_resolve_samples: Array[float] = []
	var candidate_evidence_samples: Array[float] = []
	var binding := RunState.action_authority_table_binding("slot", run_state.current_environment)
	var order: Array = ledger.get("request_order", []) if typeof(ledger.get("request_order", [])) == TYPE_ARRAY else []
	var cache: Dictionary = ledger.get("request_cache", {}) if typeof(ledger.get("request_cache", {})) == TYPE_DICTIONARY else {}
	var latest_entry: Dictionary = cache.get(str(order.back()), {}) if not order.is_empty() and typeof(cache.get(str(order.back()), {})) == TYPE_DICTIONARY else {}
	var response: Dictionary = latest_entry.get("response", {}) if typeof(latest_entry.get("response", {})) == TYPE_DICTIONARY else {}
	for _index in range(3):
		var started := Time.get_ticks_usec()
		ActionAuthority.validate_persisted_ledger_cow(ledger, binding, run_state.action_authority_checkpoint_fingerprint())
		validation_samples.append(float(Time.get_ticks_usec() - started))
		started = Time.get_ticks_usec()
		ActionAuthority.result_fingerprint(response)
		response_fingerprint_samples.append(float(Time.get_ticks_usec() - started))
		started = Time.get_ticks_usec()
		var candidate := run_state.detached_host_resolution_candidate(FOREGROUND_STATE_KEY, true)
		candidate_detach_samples.append(float(Time.get_ticks_usec() - started))
		var profile_rng := run_state.create_rng("slot_foreground_profile")
		started = Time.get_ticks_usec()
		app.get("current_game").call("_machine_game_resolve_candidate", "spin", 2, candidate, profile_rng, {})
		candidate_resolve_samples.append(float(Time.get_ticks_usec() - started))
		started = Time.get_ticks_usec()
		app.get("current_game").call("_machine_game_authority_evidence", candidate, "spin", 2, {})
		candidate_evidence_samples.append(float(Time.get_ticks_usec() - started))
	return {
		"machine_bytes": JSON.stringify(machine).length(),
		"ledger_bytes": JSON.stringify(ledger).length(),
		"latest_response_bytes": JSON.stringify(response).length(),
		"ledger_validation_avg_ms": _average(validation_samples) / 1000.0,
		"response_fingerprint_avg_ms": _average(response_fingerprint_samples) / 1000.0,
		"candidate_detach_avg_ms": _average(candidate_detach_samples) / 1000.0,
		"candidate_resolve_avg_ms": _average(candidate_resolve_samples) / 1000.0,
		"candidate_evidence_avg_ms": _average(candidate_evidence_samples) / 1000.0,
	}


func _settle(frame_count: int) -> void:
	for _index in range(maxi(0, frame_count)):
		await process_frame


func _fail(message: String) -> void:
	failures.append(message)


func _finish() -> void:
	if app != null:
		var save_service: SaveService = app.get("save_service")
		if save_service != null:
			save_service.clear_run(SAVE_SLOT)
		app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
