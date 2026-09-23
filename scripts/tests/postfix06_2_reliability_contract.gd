extends SceneTree

const FoundationMainScript := preload("res://scripts/ui/foundation_main.gd")
const ProceduralMusicPlayerScript := preload("res://scripts/ui/procedural_music_player.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

var failures: Array[String] = []


class AlwaysFailSaveService extends SaveService:
	var begin_count := 0
	var _contract_in_flight := false

	func begin_save_run(_run_state: RunState, _slot_id: String = "autosave") -> Error:
		begin_count += 1
		_contract_in_flight = true
		return OK

	func async_save_in_flight() -> bool:
		return _contract_in_flight

	func poll_async_save() -> Dictionary:
		if not _contract_in_flight:
			return {"completed": false, "in_flight": false}
		_contract_in_flight = false
		return {
			"completed": true,
			"in_flight": false,
			"ok": false,
			"error": ERR_CANT_CREATE,
			"error_code": "contract_permanent_failure",
		}

	func has_run(_slot_id: String = "autosave") -> bool:
		return false


class SequencedSaveService extends SaveService:
	var begin_count := 0
	var completion_errors: Array[int] = []
	var _contract_in_flight := false

	func begin_save_run(_run_state: RunState, _slot_id: String = "autosave") -> Error:
		begin_count += 1
		_contract_in_flight = true
		return OK

	func async_save_in_flight() -> bool:
		return _contract_in_flight

	func poll_async_save() -> Dictionary:
		if not _contract_in_flight:
			return {"completed": false, "in_flight": false}
		_contract_in_flight = false
		var error: int = completion_errors.pop_front() if not completion_errors.is_empty() else OK
		return {
			"completed": true,
			"in_flight": false,
			"ok": error == OK,
			"error": error,
			"error_code": "contract_transient_failure" if error != OK else "",
		}

	func has_run(_slot_id: String = "autosave") -> bool:
		return false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var user_args := OS.get_cmdline_user_args()
	_check_feature_pcm_budget()
	if not user_args.has("--only-audio"):
		await _check_permanent_autosave_failure()
		await _check_inflight_new_generation_after_permanent_failure()
		await _check_transient_autosave_backoff()
	if failures.is_empty():
		print("POSTFIX06_2_RELIABILITY PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_feature_pcm_budget() -> void:
	var player := ProceduralMusicPlayerScript.new()
	# Exercise more than the 24-key reproducer across repeated run boundaries.
	# The delivered audio has only two physical styles and must not be decoded
	# into a new retained pack for each contextual request or retain bytes after
	# any run-scoped cleanup.
	for boundary_index in range(3):
		for index in range(32):
			player.set("_current_stem_set", {
				"bpm": 70.0 + float(index),
				"profile": {
					"palette_id": "postfix_palette_%d_%02d" % [boundary_index, index],
					"theme": "slot",
					"root_midi": 45,
				},
			})
			player.call("_feature_stem_set_for_input", {
				"cue_id": "buffalo_feature_%d_%02d" % [boundary_index, index] if index % 2 == 0 else "pinball_feature_%d_%02d" % [boundary_index, index],
			})
		var populated: Dictionary = player.call("debug_soak_snapshot")
		var policy: Dictionary = player.call("pcm_cache_policy_snapshot")
		var retained_entries := int(populated.get("feature_stem_cache_size", -1))
		var retained_bytes := int(policy.get("bytes", -1))
		var budget_bytes := int(policy.get("budget_bytes", -1))
		_expect(retained_entries == 2, "RP-006 boundary %d: contextual feature requests retained %d packs instead of the two delivery styles." % [boundary_index, retained_entries])
		_expect(retained_bytes > 0, "RP-006 boundary %d: feature PCM is absent from shared cache telemetry." % boundary_index)
		_expect(retained_bytes <= budget_bytes, "RP-006 boundary %d: feature PCM retained %d bytes beyond the %d-byte shared budget." % [boundary_index, retained_bytes, budget_bytes])

		player.call("clear_run_scoped_caches")
		var cleared: Dictionary = player.call("debug_soak_snapshot")
		var cleared_policy: Dictionary = player.call("pcm_cache_policy_snapshot")
		_expect(int(cleared.get("feature_stem_cache_size", -1)) == 0, "RP-006 boundary %d: feature PCM survived run-scoped cache cleanup." % boundary_index)
		_expect(int(cleared_policy.get("bytes", -1)) == 0, "RP-006 boundary %d: shared PCM telemetry retained bytes after run cleanup." % boundary_index)
	_check_feature_pcm_lru_style_switch(player)
	player.free()


func _check_feature_pcm_lru_style_switch(player: ProceduralMusicPlayer) -> void:
	player.set("_current_stem_set", {
		"bpm": 92.0,
		"profile": {"palette_id": "postfix_switch_buffalo", "theme": "slot", "root_midi": 45},
	})
	var first: Dictionary = player.call("_feature_stem_set_for_input", {"cue_id": "buffalo_feature_switch_a"})
	var first_key := str(first.get("pcm_cache_key", ""))
	var first_policy: Dictionary = player.call("pcm_cache_policy_snapshot")
	var first_entry_bytes: Dictionary = first_policy.get("entry_bytes", {}) if typeof(first_policy.get("entry_bytes", {})) == TYPE_DICTIONARY else {}
	var first_bytes := int(first_entry_bytes.get(first_key, 0))
	_expect(not first_key.is_empty() and first_bytes > 0, "RP-006: style-switch fixture could not account the first delivered feature pack.")
	player.set("_current_feature_cache_key", first_key)
	player.call("debug_configure_pcm_cache_budget", maxi(1, first_bytes))

	player.set("_current_stem_set", {
		"bpm": 108.0,
		"profile": {"palette_id": "postfix_switch_arcade", "theme": "slot", "root_midi": 52},
	})
	var second: Dictionary = player.call("_feature_stem_set_for_input", {"cue_id": "pinball_feature_switch_b"})
	var second_key := str(second.get("pcm_cache_key", ""))
	var inserted_policy: Dictionary = player.call("pcm_cache_policy_snapshot")
	var inserted_bytes: Dictionary = inserted_policy.get("entry_bytes", {}) if typeof(inserted_policy.get("entry_bytes", {})) == TYPE_DICTIONARY else {}
	_expect(second_key != first_key and int(inserted_bytes.get(second_key, 0)) > 0, "RP-006: next feature style evicted itself before playback could own/account it.")

	# Model the synchronous handoff performed immediately after lookup. Once the
	# new style is current, the old style must become the LRU victim and telemetry
	# must describe the retained playback pack within the shared budget.
	player.set("_current_feature_cache_key", second_key)
	player.call("debug_configure_pcm_cache_budget", maxi(1, first_bytes))
	var switched_policy: Dictionary = player.call("pcm_cache_policy_snapshot")
	var switched_bytes: Dictionary = switched_policy.get("entry_bytes", {}) if typeof(switched_policy.get("entry_bytes", {})) == TYPE_DICTIONARY else {}
	_expect(int(switched_bytes.get(second_key, 0)) > 0 and not switched_bytes.has(first_key), "RP-006: style switch retained the old pack or lost accounting for the active pack.")
	_expect(int(switched_policy.get("bytes", -1)) <= int(switched_policy.get("budget_bytes", -1)), "RP-006: style-switch cache did not return under the shared PCM budget.")
	player.call("clear_run_scoped_caches")
	var cleared_policy: Dictionary = player.call("pcm_cache_policy_snapshot")
	_expect(int(cleared_policy.get("bytes", -1)) == 0, "RP-006: style-switch PCM survived run-scoped cleanup.")


func _check_permanent_autosave_failure() -> void:
	var app := FoundationMainScript.new()
	var service := AlwaysFailSaveService.new()
	var run := RunStateScript.new()
	run.start_new("POSTFIX06_2_AUTOSAVE")
	app.set("run_state", run)
	app.set("save_service", service)
	app.set("pending_autosave", true)
	app.set("pending_autosave_after_frame", -1)
	app.set("pending_autosave_not_before_msec", 0)
	app.set("autosave_dirty_generation", 1)
	for _index in range(20):
		app.call("_flush_pending_autosave_if_ready")
		await process_frame
	_expect(service.begin_count == 1, "RP-007: a permanent autosave failure was automatically retried %d times in 20 frames." % service.begin_count)
	_expect(bool(app.get("pending_autosave")), "RP-007: the dirty autosave generation was discarded after a permanent failure.")
	_expect(str(app.get("save_status_message")).findn("retry") >= 0, "RP-007: permanent autosave failure did not expose a meaningful retry/recovery status.")
	var blocked_status: Dictionary = app.call("autosave_recovery_snapshot")
	_expect(bool(blocked_status.get("retry_blocked", false)) and int(blocked_status.get("failure_count", 0)) == 1, "RP-007: permanent failure diagnostics did not expose the latched error.")

	_expect(bool(app.call("retry_failed_autosave")), "RP-007: explicit autosave retry was unavailable.")
	for _index in range(3):
		await process_frame
		app.call("_flush_pending_autosave_if_ready")
	_expect(service.begin_count == 2 and bool(app.get("autosave_retry_blocked")), "RP-007: explicit retry did not issue exactly one new save attempt.")

	app.call("_queue_pending_autosave", "New generation.", 0)
	app.set("pending_autosave_after_frame", -1)
	app.set("pending_autosave_not_before_msec", 0)
	for _index in range(2):
		app.call("_flush_pending_autosave_if_ready")
		await process_frame
	_expect(service.begin_count == 3, "RP-007: a new dirty generation did not unlock exactly one save attempt.")
	app.free()


func _check_inflight_new_generation_after_permanent_failure() -> void:
	var app := FoundationMainScript.new()
	var service := AlwaysFailSaveService.new()
	var run := RunStateScript.new()
	run.start_new("POSTFIX06_2_AUTOSAVE_INFLIGHT_GENERATION")
	app.set("run_state", run)
	app.set("save_service", service)
	app.set("pending_autosave", true)
	app.set("pending_autosave_after_frame", -1)
	app.set("pending_autosave_not_before_msec", 0)
	app.set("autosave_dirty_generation", 1)
	app.call("_flush_pending_autosave_if_ready")
	_expect(service.begin_count == 1 and service.async_save_in_flight(), "RP-007: generation one did not enter flight for the overlap fixture.")

	# A real second action can become dirty while generation one is still being
	# written. Its existence must not let generation one's completion failure be
	# misattributed to generation two and latch generation two unattempted.
	app.call("_queue_pending_autosave", "New in-flight generation.", 0)
	app.set("pending_autosave_after_frame", -1)
	app.set("pending_autosave_not_before_msec", 0)
	app.call("_flush_pending_autosave_if_ready")
	var first_failure: Dictionary = app.call("autosave_recovery_snapshot")
	_expect(int(first_failure.get("failure_generation", -1)) == 1, "RP-007: generation-one failure was attributed to unattempted generation %d." % int(first_failure.get("failure_generation", -1)))
	_expect(not bool(first_failure.get("retry_blocked", true)), "RP-007: a newer dirty generation was latched before it received one save attempt.")

	for _index in range(4):
		await process_frame
		app.call("_flush_pending_autosave_if_ready")
	_expect(service.begin_count == 2, "RP-007: newer dirty generation was not attempted exactly once after the in-flight generation failed (began %d saves)." % service.begin_count)
	# Complete generation two's own failure. Only now may its permanent error be
	# latched for explicit retry or a subsequent dirty generation.
	app.call("_flush_pending_autosave_if_ready")
	var second_failure: Dictionary = app.call("autosave_recovery_snapshot")
	_expect(bool(second_failure.get("retry_blocked", false)) and int(second_failure.get("failure_generation", -1)) == 2, "RP-007: generation two did not latch only after its own permanent failure: %s" % JSON.stringify(second_failure))
	app.free()


func _check_transient_autosave_backoff() -> void:
	var app := FoundationMainScript.new()
	if not app.has_method("_autosave_retry_delay_msec"):
		_expect(false, "RP-007: production exposes no directly testable capped autosave retry-delay policy.")
		app.free()
		return
	var service := SequencedSaveService.new()
	service.completion_errors = [ERR_TIMEOUT, ERR_TIMEOUT, ERR_TIMEOUT, ERR_TIMEOUT, ERR_TIMEOUT, ERR_TIMEOUT, OK]
	var run := RunStateScript.new()
	run.start_new("POSTFIX06_2_AUTOSAVE_TRANSIENT")
	app.set("run_state", run)
	app.set("save_service", service)
	app.set("pending_autosave", true)
	app.set("pending_autosave_after_frame", -1)
	app.set("pending_autosave_not_before_msec", 0)
	app.set("autosave_dirty_generation", 1)
	var expected_delays := [1000, 2000, 4000, 8000, 16000, 30000]
	for failure_index in range(expected_delays.size()):
		var expected_delay := int(expected_delays[failure_index])
		_expect(int(app.call("_autosave_retry_delay_msec", failure_index + 1)) == expected_delay, "RP-007: retry delay %d did not follow the capped exponential schedule." % (failure_index + 1))
		app.call("_flush_pending_autosave_if_ready")
		await process_frame
		app.call("_flush_pending_autosave_if_ready")
		var snapshot: Dictionary = app.call("autosave_recovery_snapshot")
		if failure_index < expected_delays.size() - 1:
			var remaining_delay := int(snapshot.get("retry_not_before_msec", 0)) - Time.get_ticks_msec()
			_expect(service.begin_count == failure_index + 1 and not bool(snapshot.get("retry_blocked", true)), "RP-007: transient failure %d did not remain scheduled." % (failure_index + 1))
			_expect(remaining_delay > maxi(0, expected_delay - 250) and remaining_delay <= expected_delay, "RP-007: transient failure %d scheduled %d ms instead of the %d ms capped delay." % [failure_index + 1, remaining_delay, expected_delay])
			for _index in range(3):
				app.call("_flush_pending_autosave_if_ready")
				await process_frame
			_expect(service.begin_count == failure_index + 1, "RP-007: backoff attempt %d serialized again before its deadline." % (failure_index + 1))
			app.set("pending_autosave_not_before_msec", 0)
			app.set("pending_autosave_after_frame", -1)
		else:
			_expect(service.begin_count == 6 and bool(snapshot.get("retry_blocked", false)) and int(snapshot.get("failure_count", 0)) == 6, "RP-007: transient retry limit did not latch after six failed attempts: %s" % JSON.stringify(snapshot))

	_expect(bool(app.call("retry_failed_autosave")), "RP-007: explicit recovery was unavailable after the transient retry cap.")
	app.set("pending_autosave_after_frame", -1)
	app.call("_flush_pending_autosave_if_ready")
	await process_frame
	app.call("_flush_pending_autosave_if_ready")
	_expect(service.begin_count == 7 and not bool(app.get("pending_autosave")) and int(app.get("autosave_failure_count")) == 0, "RP-007: successful explicit retry did not clear pending/failure state after the retry cap.")
	app.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
