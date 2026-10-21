extends SceneTree

# One synthetic Punchline event -> rendered chair command. The parent supplies
# the disposable project/user directory, OS job cap and external deadline.
# No original browser, profile or preserved save is read by this script.
const SEED := "PUNCHLINE-WITNESS-CHAIRS-ONE"
const SCENARIO_ID := "punchline_debt_court"
const EVENT_ID := "scenario_debt_court_office_hours"
const CHOICE_ID := "watch_the_next_name"
const CHAIR_ID := "scenario::punchline_debt_court_hearing_chairs"

var failures: Array[String] = []
var observations: Dictionary = {"fixture": "Punchline synthetic; no preserved user save", "seed": SEED, "stage": "punchline_fresh"}
var app: Control
var run: RecordingRun
var finished := false


class RecordingRun:
	extends RunState

	var repro_phase := "setup"
	var trace: Array = []

	func _summary(result: Dictionary) -> Dictionary:
		var state: Dictionary = current_environment.get("scenario_sequence_state", {})
		return {
			"phase": repro_phase, "ok": bool(result.get("ok", false)),
			"errors": (result.get("errors", []) as Array).duplicate(true),
			"inactive": bool(result.get("inactive", false)), "ignored": bool(result.get("ignored", false)),
			"replayed": bool(result.get("replayed", false)), "cost": int(result.get("cost", 0)),
			"receipt_id": str(result.get("receipt_id", "")),
			"state_phase": str(state.get("phase_id", "")),
			"fact_queue_count": (state.get("fact_queue", []) as Array).size(),
			"fact_receipt_count": (state.get("fact_receipts", []) as Array).size(),
			"command_receipt_count": (state.get("command_receipts", []) as Array).size(),
		}

	func _record(value: Dictionary) -> void:
		if trace.size() < 32:
			trace.append(value)

	func scenario_enqueue_fact(fact_type: String, producer: String, payload: Dictionary = {}, fact_id: String = "", node_id: String = "") -> Dictionary:
		var result := super.scenario_enqueue_fact(fact_type, producer, payload, fact_id, node_id)
		if fact_type == "event_result":
			var entry := _summary(result)
			entry["operation"] = "enqueue_event_result"
			entry["payload"] = payload.duplicate(true)
			_record(entry)
		return result

	func scenario_flush_facts(boundary_serial: int = -1) -> Dictionary:
		var result := super.scenario_flush_facts(boundary_serial)
		var entry := _summary(result)
		entry["operation"] = "flush_facts"
		entry["requested_boundary"] = boundary_serial
		entry["processed_count"] = (result.get("processed", []) as Array).size()
		_record(entry)
		return result

	func scenario_sequence_command(command_id: String, idempotency_key: String, payload: Dictionary = {}, owner_namespace: String = "scenario", stable_object_id: String = "sequence", host_interaction_availability: Dictionary = {}, action_origin_owner_namespace: String = "", action_origin_stable_object_id: String = "", action_origin_receipt_key: String = "", action_origin_boundary_id: String = "", action_origin_fingerprint: String = "") -> Dictionary:
		var before: Dictionary = current_environment.get("scenario_sequence_state", {})
		var phase_before := str(before.get("phase_id", ""))
		var result := super.scenario_sequence_command(command_id, idempotency_key, payload, owner_namespace, stable_object_id, host_interaction_availability, action_origin_owner_namespace, action_origin_stable_object_id, action_origin_receipt_key, action_origin_boundary_id, action_origin_fingerprint)
		var entry := _summary(result)
		entry["operation"] = "scenario_command"
		entry["command_id"] = command_id
		entry["phase_before"] = phase_before
		entry["owner_namespace"] = owner_namespace
		entry["stable_object_id"] = stable_object_id
		entry["action_origin_owner_namespace"] = action_origin_owner_namespace
		entry["action_origin_stable_object_id"] = action_origin_stable_object_id
		entry["origin_receipt_present"] = not action_origin_receipt_key.is_empty()
		entry["origin_fingerprint_present"] = not action_origin_fingerprint.is_empty()
		_record(entry)
		return result


func _init() -> void:
	# FIRST operation: before any scene, run, profile or authority construction.
	if not _disposable_userdata_confirmed():
		push_error("REFUSED: resolved user:// must exactly equal BTH_SCRATCH_REPRO_USER_DIR.")
		quit(64)
		return
	if not OS.get_cmdline_user_args().has("--punchline-repro-authorized"):
		push_error("REFUSED: --punchline-repro-authorized is required.")
		quit(64)
		return
	if OS.get_environment("BTH_SCRATCH_REPRO_REPORT").is_empty():
		push_error("REFUSED: BTH_SCRATCH_REPRO_REPORT must name the parent's local report.")
		quit(64)
		return
	call_deferred("_run")


func _run() -> void:
	create_timer(45.0).timeout.connect(func() -> void:
		if not finished:
			failures.append("In-engine 45s deadline expired; this is a setup/timeout failure.")
			_finish(124)
	)
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	app = main_scene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", "punchline_witness_chairs_disposable")
	root.add_child(app)
	await process_frame
	await process_frame
	if not _require(bool(app.call("_ensure_run_ui_built")), "Normal host UI construction failed."):
		_finish()
		return
	app.call("_ensure_full_content_library_loaded")
	var library: ContentLibrary = app.get("library")
	run = RecordingRun.new()
	run.start_new(SEED, RunState.custom_challenge("punchline_witness_chairs", SEED, {
		"scenario_pins": {"small_underground_casino": SCENARIO_ID},
	}))
	# Set fixture clock before normal generation/installation, never by rewriting
	# sealed sequence state. 7515 = Day 6, 05:15 at the normal day-one origin.
	run.game_clock_minutes = 7515
	run.bankroll = 25
	run.begin_act(1)
	var generator := RunGenerator.new(library)
	var installed := generator.travel_environment_result(run, "small_underground_casino", true)
	observations["install"] = {"ok": bool(installed.get("ok", false)), "errors": (installed.get("errors", []) as Array).duplicate(true)}
	if not _require(bool(installed.get("ok", false)), "Normal pinned Punchline install failed."):
		_finish()
		return
	# Use the ordinary local-heat API. Fresh normal runs start sober; do not
	# replace suspicion structures or force authored scenario flags.
	run.add_suspicion("punchline_repro_setup", 3 - run.suspicion_level(), "behavior", false)
	var interaction_script: Script = load("res://scripts/ui/environment_interaction_controller.gd")
	var proof: Dictionary = interaction_script._object_manifest_join_proof(run.current_environment.duplicate(true))
	observations["baseline_raw_join_proof"] = {"ok": bool(proof.get("ok", false)), "errors": (proof.get("errors", []) as Array).duplicate(true)}
	if not _require(bool(proof.get("ok", false)), "Normal factory baseline failed raw detached manifest join proof."):
		_finish()
		return
	var terminal := RunTerminalEvaluator.evaluate(run, library)
	observations["baseline_terminal_decision"] = terminal.duplicate(true)
	if not _require(not bool(terminal.get("failed", false)) and bool(terminal.get("event_recovery_available", false)), "The authored free Side Door recovery was misclassified as stranded."):
		_finish()
		return
	app.set("run_state", run)
	app.set("generator", generator)
	app.call("_bind_run_state_presentation_signals")
	app.call("_configure_coach_for_run")
	app.call("_refresh_run_action_service")
	app.call("_clear_input_guard_modal_state")
	app.call("_queue_room_publication_check")
	app.call("_set_current_screen", "ENVIRONMENT")
	app.call("_refresh")
	await process_frame
	await process_frame
	var baseline := _snapshot("baseline")
	if not _require(str(run.current_environment.get("scenario_id", "")) == SCENARIO_ID, "Normal factory did not install the authored Debt Court pin.") \
		or not _require(not run.is_tutorial_run() and not bool(app.call("_is_environment_test_session")), "Fixture is not a normal, non-tutorial run.") \
		or not _require(run.game_clock_minutes == 7515 and run.bankroll == 25 and run.suspicion_level() == 3 and run.drunk_level == 0, "Fixture clock/bankroll/heat/sobriety did not match the requested setup.") \
		or not _require(bool(run.call("_scenario_semantic_ready")), "Baseline scenario semantic authority failed.") \
		or not _require(int(baseline.get("enabled_room_objects", 0)) > 0, "Baseline room has no enabled objects."):
		_finish()
		return
	run.repro_phase = "collector_open"
	var event_opened := bool(app.call("activate_interactable_object", "event:%s" % EVENT_ID))
	observations["collector_opened_through_host"] = event_opened
	await process_frame
	_snapshot("collector_open")
	if not _require(event_opened, "The normal visible Collector event could not be opened through the host."):
		_finish()
		return
	run.repro_phase = "watch_next_name"
	# Same host resolver used by the real TalkDock response. It retains the
	# pending conversation context and the complete lifecycle transaction.
	var event_result: Dictionary = app.call("resolve_event_choice", EVENT_ID, CHOICE_ID)
	observations["event_host_result"] = _result_summary(event_result)
	await process_frame
	await process_frame
	_snapshot("after_event")
	var post_event_proof: Dictionary = interaction_script._object_manifest_join_proof(run.current_environment.duplicate(true))
	observations["after_event_raw_join_proof"] = {"ok": bool(post_event_proof.get("ok", false)), "errors": (post_event_proof.get("errors", []) as Array).duplicate(true)}
	observations["after_event_semantic_ready"] = bool(run.call("_scenario_semantic_ready"))
	_require(not run.is_terminal(), "The accepted ordinary Collector event ended a recoverable run.")
	if not _require(bool(event_result.get("ok", false)), "The Collector Watch the next name event itself rejected; no chair command was forced."):
		_finish()
		return
	# One detached same-state turn attempt tests the queue independently of the
	# rendered chair command (which does not advance room turns). Never apply
	# this probe to the live host run and never clear or repair its queued fact.
	var original_queue_text := JSON.stringify((run.current_environment.get("scenario_sequence_state", {}) as Dictionary).get("fact_queue", []))
	var detached := RunState.new()
	detached.from_dict(run.to_dict().duplicate(true))
	if not _require(detached.restore_trusted_scenario_semantics(run.current_environment), "Detached diagnostic could not restore the exact trusted source semantics."):
		_finish()
		return
	var detached_before_state: Dictionary = detached.current_environment.get("scenario_sequence_state", {})
	var detached_before_queue_text := JSON.stringify(detached_before_state.get("fact_queue", []))
	var detached_phase_before := str(detached_before_state.get("phase_id", ""))
	var detached_queue_count_before := (detached_before_state.get("fact_queue", []) as Array).size()
	var detached_turn := detached.advance_environment_turns(1)
	var detached_after_state: Dictionary = detached.current_environment.get("scenario_sequence_state", {})
	observations["detached_one_turn_probe"] = {
		"ok": bool(detached_turn.get("ok", false)), "applied": bool(detached_turn.get("applied", false)),
		"errors": (detached_turn.get("errors", []) as Array).duplicate(true),
		"phase_before": detached_phase_before, "phase_after": str(detached_after_state.get("phase_id", "")),
		"queue_count_before": detached_queue_count_before,
		"queue_count_after": (detached_after_state.get("fact_queue", []) as Array).size(),
		"copy_queue_matches_original_before_turn": detached_before_queue_text == original_queue_text,
		"copy_queue_unchanged_after_turn": JSON.stringify(detached_after_state.get("fact_queue", [])) == detached_before_queue_text,
		"original_queue_unchanged": JSON.stringify((run.current_environment.get("scenario_sequence_state", {}) as Dictionary).get("fact_queue", [])) == original_queue_text,
	}
	_require(bool(observations["detached_one_turn_probe"]["original_queue_unchanged"]), "Detached turn probe changed the live host's queued facts.")
	_require(bool(detached_turn.get("ok", false)) and bool(detached_turn.get("applied", false)), "Ordinary Collector result poisoned the next real environment turn.")
	_require((run.current_environment.get("scenario_sequence_state", {}) as Dictionary).get("fact_queue", []).is_empty(), "Accepted ordinary Collector fact remained pending after the event boundary.")
	_check_forged_correlations()
	var canvas: Control = app.get("environment_canvas")
	if not _require(canvas != null, "Normal room canvas is absent after the Collector event."):
		_finish()
		return
	canvas.call("set_selected_object", CHAIR_ID)
	var chair: Dictionary = canvas.call("_scene_object", CHAIR_ID)
	var chair_action := {"label": str(canvas.call("_selected_info_action_label", chair)), "confirm_action_id": str(chair.get("confirm_action_id", "")), "enabled": bool(canvas.call("_selected_info_single_action_enabled", chair))}
	observations["rendered_chair_action"] = chair_action.duplicate(true)
	_snapshot("before_chair")
	if not _require(not chair.is_empty() and str(chair_action.get("label", "")).to_lower() == "form hearing aisle" and bool(chair_action.get("enabled", false)), "The actual rendered Debt-court chairs lack enabled Form Hearing Aisle."):
		_finish()
		return
	run.repro_phase = "form_hearing_aisle"
	_require(bool(canvas.call("_activate_selected_info_action_by_index")), "The actual selected chair button refused activation.")
	await process_frame
	await process_frame
	var deadline := Time.get_ticks_msec() + 5000
	while bool(app.get("scenario_sequence_action_pending")):
		if Time.get_ticks_msec() >= deadline:
			_require(false, "Deferred chair command did not release its pending gate within 5s.")
			break
		await process_frame
	var after := _snapshot("after_chair")
	var command_result: Dictionary = {}
	for entry in run.trace:
		if str(entry.get("operation", "")) == "scenario_command" and str(entry.get("command_id", "")) == "form_hearing_aisle":
			command_result = entry
	observations["exact_deferred_command_result"] = command_result.duplicate(true)
	_require(not command_result.is_empty(), "Rendered chair input never reached RunState.scenario_sequence_command; inspect the recorded gates.")
	_require(bool(command_result.get("ok", false)), "The real deferred Form Hearing Aisle command rejected.")
	_require(str(after.get("sequence_phase", "")) == "work_1", "Form Hearing Aisle did not advance arrival to work_1.")
	_require(int(after.get("bankroll", -1)) == 25, "The no-cost witness/chair sequence changed bankroll.")
	_require(int(after.get("enabled_room_objects", 0)) > 0, "The witness/chair sequence left no enabled room objects.")
	if not failures.is_empty():
		_finish()
		return
	# Prior ordinary Watch must not block the later authored witness command or
	# the remaining physical hearing work. The original five-field bridge stays
	# in the definition; its already-resolved event cannot pay or resolve again.
	for label in ["Place Public Evidence", "Call a Room Witness", "Clear Chairs For Work"]:
		if not await _activate_rendered_action(label):
			_finish()
			return
	var hearing_state: Dictionary = run.current_environment.get("scenario_sequence_state", {})
	var hearing_outcomes: Array = hearing_state.get("resolved_outcomes", [])
	observations["hearing_outcomes"] = hearing_outcomes.duplicate(true)
	observations["hearing_completed_after_ordinary_watch"] = hearing_outcomes.has("room_returns_ordered")
	_require(hearing_outcomes.has("room_returns_ordered"), "The later witness bridge/physical hearing did not finish after ordinary Watch.")
	_require(run.bankroll == 25 and bool(run.narrative_flags.get("debt_court_witness_beat", false)), "The repeated witness beat changed money or lost the already-completed witness flag.")
	_require(str(app.call("_blocking_modal_message")).is_empty(), "The later witness bridge left a blocking modal.")
	# The free authored discovery is also exercised through its normal host,
	# rather than merely counting it as a speculative terminal escape.
	var side_opened := bool(app.call("activate_interactable_object", "event:side_door"))
	observations["side_door_opened"] = side_opened
	if not _require(side_opened, "The free Side Door event could not be opened."):
		_finish()
		return
	var side_result: Dictionary = app.call("resolve_event_choice", "side_door", "punchline_password")
	observations["side_door_result"] = _result_summary(side_result)
	await process_frame
	await process_frame
	_require(bool(side_result.get("ok", false)) and str(run.current_environment.get("current_layer_id", "")) == "casino", "The free authored password choice did not enter the casino.")
	_require(run.bankroll == 25 and not run.is_terminal(), "Free casino discovery changed cash or terminated the run.")
	var other_game_opened := false
	var casino_canvas: Control = app.get("environment_canvas")
	for value in casino_canvas.get("foundation_scene_objects"):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = value
		var identity := str(object_data.get("id", ""))
		if identity.begins_with("game:") and bool(object_data.get("interactive", false)) and not bool(object_data.get("disabled", false)):
			other_game_opened = bool(app.call("activate_interactable_object", identity)) and str(app.get("current_screen")) == "GAME"
			observations["other_room_object"] = identity
			app.call("back_to_environment")
			await process_frame
			await process_frame
			break
	_require(other_game_opened, "A real casino game could not open after the Collector/chair/Side Door sequence.")
	var final_proof: Dictionary = interaction_script._object_manifest_join_proof(run.current_environment.duplicate(true))
	observations["final_strict_join"] = {"ok": bool(final_proof.get("ok", false)), "errors": final_proof.get("errors", [])}
	_require(bool(final_proof.get("ok", false)), "Final casino room failed strict authority.")
	var saved := bool(app.call("_autosave_foundation_run", "Punchline recovery qualified", true))
	observations["real_host_save_succeeded"] = saved
	_require(saved, "Normal host Save rejected the qualified Punchline sequence.")
	_finish()


func _activate_rendered_action(label: String) -> bool:
	var canvas: Control = app.get("environment_canvas")
	var chosen := false
	var inspected := 0
	for value in canvas.get("foundation_scene_objects"):
		inspected += 1
		if inspected > 64 or typeof(value) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = value
		var identity := str(object_data.get("id", ""))
		canvas.call("set_selected_object", identity)
		if str(canvas.call("_selected_info_action_label", object_data)).to_lower() == label.to_lower() and bool(canvas.call("_selected_info_single_action_enabled", object_data)):
			chosen = true
			break
	if not _require(chosen, "Missing real rendered hearing action: %s" % label):
		return false
	var prior_count := run.trace.size()
	if not _require(bool(canvas.call("_activate_selected_info_action_by_index")), "The selected hearing button refused activation: %s" % label):
		return false
	await process_frame
	await process_frame
	var deadline := Time.get_ticks_msec() + 5000
	while bool(app.get("scenario_sequence_action_pending")):
		if Time.get_ticks_msec() >= deadline:
			return _require(false, "Hearing action pending gate timed out: %s" % label)
		await process_frame
	var reached := false
	for index in range(prior_count, run.trace.size()):
		var entry: Dictionary = run.trace[index]
		if str(entry.get("operation", "")) == "scenario_command":
			reached = true
			_require(bool(entry.get("ok", false)), "Hearing action rejected: %s" % label)
	return _require(reached, "Hearing action never reached its command owner: %s" % label) and failures.is_empty()


func _check_forged_correlations() -> void:
	var runtime: Script = load("res://scripts/core/scenario_sequence_runtime.gd")
	var state: Dictionary = run.current_environment.get("scenario_sequence_state", {})
	var definition: Dictionary = run.call("_scenario_sequence_definition_readonly")
	var ordinary := {"event_id": EVENT_ID, "choice_id": CHOICE_ID, "resolution_id": "", "ok": true, "resolved": true}
	var forged := ordinary.duplicate(true)
	forged["resolution_id"] = "not_requested"
	var failed := ordinary.duplicate(true)
	failed["ok"] = false
	var unresolved := ordinary.duplicate(true)
	unresolved["resolved"] = false
	observations["event_authority_negatives"] = {
		"unrequested_correlation_rejected": not bool(runtime._event_fact_is_authorized(state, definition, forged)),
		"failed_result_rejected": not bool(runtime._event_fact_is_authorized(state, definition, failed)),
		"unresolved_result_rejected": not bool(runtime._event_fact_is_authorized(state, definition, unresolved)),
	}
	for value in observations["event_authority_negatives"].values():
		_require(bool(value), "Explicit ordinary observers weakened event-result authority.")


func _result_summary(result: Dictionary) -> Dictionary:
	var deltas: Dictionary = result.get("deltas", {})
	return {
		"ok": bool(result.get("ok", false)), "errors": (result.get("errors", []) as Array).duplicate(true),
		"message": str(result.get("message", "")), "event_id": str(result.get("event_id", result.get("source_id", ""))),
		"choice_id": str(result.get("choice_id", result.get("action_id", ""))),
		"resolution_id": str(result.get("resolution_id", "")), "resolved": bool(result.get("resolved", false)),
		"bankroll_delta": int(deltas.get("bankroll_delta", 0)), "flags_set": (deltas.get("flags_set", {}) as Dictionary).duplicate(true),
	}


func _snapshot(label: String) -> Dictionary:
	var environment := run.current_environment
	var state: Dictionary = environment.get("scenario_sequence_state", {})
	var facts: Array = []
	for value in state.get("fact_queue", []):
		if facts.size() >= 8:
			break
		var fact: Dictionary = value
		facts.append({"type": str(fact.get("type", fact.get("fact_type", ""))), "fact_id": str(fact.get("fact_id", "")), "boundary_serial": int(fact.get("boundary_serial", -1)), "payload": (fact.get("payload", {}) as Dictionary).duplicate(true)})
	var objects: Array = []
	var enabled_count := 0
	var canvas: Control = app.get("environment_canvas")
	if canvas != null:
		for value in canvas.get("foundation_scene_objects"):
			if typeof(value) != TYPE_DICTIONARY:
				continue
			var object_data: Dictionary = value
			var enabled := bool(object_data.get("interactive", false)) and not bool(object_data.get("decorative", false)) and not bool(object_data.get("disabled", false)) and not str(object_data.get("id", "")).is_empty()
			if enabled:
				enabled_count += 1
			if objects.size() < 32:
				objects.append({"id": str(object_data.get("id", "")), "enabled": enabled, "disabled_reason": str(object_data.get("disabled_reason", ""))})
	var result := {
		"clock": run.game_clock_minutes, "bankroll": run.bankroll, "heat": run.suspicion_level(), "drunk": run.drunk_level,
		"run_status": run.run_status, "run_failure_reason": run.run_failure_reason, "current_screen": str(app.get("current_screen")),
		"scenario_id": str(environment.get("scenario_id", "")), "layer_id": str(environment.get("current_layer_id", environment.get("layer_id", ""))),
		"sequence_phase": str(state.get("phase_id", "")), "sequence_status": str(state.get("status", "")),
		"boundary_serial": int(state.get("boundary_serial", 0)), "fact_queue_count": (state.get("fact_queue", []) as Array).size(),
		"fact_queue_first_eight": facts, "fact_receipt_count": (state.get("fact_receipts", []) as Array).size(),
		"command_receipt_count": (state.get("command_receipts", []) as Array).size(),
		"event_request_queue_count": (state.get("event_request_queue", []) as Array).size(),
		"event_request_history_count": (state.get("event_request_history", []) as Array).size(),
		"event_request_delivery_receipt_count": (state.get("event_request_delivery_receipts", []) as Array).size(),
		"witness_flag": bool(run.narrative_flags.get("debt_court_witness_beat", false)),
		"semantic_ready_flag": bool(environment.get("scenario_semantic_ready", false)),
		"lifecycle_errors": (environment.get("scenario_sequence_lifecycle_errors", []) as Array).duplicate(true),
		"sequence_errors": (state.get("errors", []) as Array).duplicate(true),
		"enabled_room_objects": enabled_count, "room_objects_first_32": objects,
		"blocking_modal_message": str(app.call("_blocking_modal_message")),
		"closing_time_blocks_actions": bool(app.call("_closing_time_blocks_environment_actions")),
		"closing_time_status": run.closing_time_status().duplicate(true),
		"simulation_paused": bool(app.call("_simulation_progression_paused")),
		"application_pause_owners": (app.get("application_pause_owners") as Dictionary).duplicate(true),
		"scenario_sequence_action_pending": bool(app.get("scenario_sequence_action_pending")),
		"event_choice_resolution_pending": bool(app.get("event_choice_resolution_pending")),
		"service_hook_resolution_locked": bool(app.get("service_hook_resolution_locked")),
		"travel_transition_active": bool(app.get("travel_transition_active")),
		"event_popup_visible": bool(app.call("_event_choice_popup_is_visible")),
		"world_map_visible": bool(app.call("_world_map_overlay_is_visible")),
		"inventory_visible": bool(app.call("_run_inventory_popup_is_visible")),
		"journal_visible": bool(app.call("_run_journal_popup_is_visible")),
		"run_menu_visible": bool(app.call("_run_menu_is_visible")),
	}
	observations[label] = result
	return result


func _disposable_userdata_confirmed() -> bool:
	var actual := ProjectSettings.globalize_path("user://")
	var expected := OS.get_environment("BTH_SCRATCH_REPRO_USER_DIR")
	var actual_directory := actual.replace("\\", "/").trim_suffix("/").to_lower()
	var expected_directory := expected.replace("\\", "/").trim_suffix("/").to_lower()
	observations["resolved_user_dir"] = actual
	observations["userdata_guard_passed"] = not expected_directory.is_empty() and actual_directory == expected_directory
	return not expected_directory.is_empty() and actual_directory == expected_directory


func _require(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
	return condition


func _finish(forced_exit_code: int = -1) -> void:
	if finished:
		return
	finished = true
	if run != null:
		observations["production_boundary_trace"] = run.trace.duplicate(true)
	observations["failures"] = failures.duplicate()
	var report_text := JSON.stringify(observations)
	var report_written := false
	if report_text.to_utf8_buffer().size() <= 65536:
		var report := FileAccess.open(OS.get_environment("BTH_SCRATCH_REPRO_REPORT"), FileAccess.WRITE)
		if report != null:
			report.store_string(report_text)
			report_written = report.get_error() == OK
			report.close()
	if app != null:
		app.queue_free()
	var exit_code := forced_exit_code if forced_exit_code >= 0 else (0 if failures.is_empty() else 1)
	if not report_written:
		exit_code = 74
	print("PUNCHLINE_SYNTHETIC_WITNESS_CHAIRS status=%s failures=%d report_written=%s" % ["PASS" if exit_code == 0 else "FAIL", failures.size(), str(report_written)])
	quit(exit_code)
