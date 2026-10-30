extends "res://scripts/tests/scenario_venue_cycle_captured_check.gd"

# Copied-state native regression; not ordinary Web visual acceptance.
# The genuine pending fixture is work_1 with coat token already accepted. Its
# filename says after-Badge, but the durable autosave still has one command.
# Submit the visible Verify and Fail choices once each; never replay the coat.
const Fingerprint := preload("res://scripts/core/game_ritual_runtime.gd")
const SCENARIO_READER := "_saved_scenario_action_feedback_from_story_log"
const SCENARIO_WRITER := "_record_scenario_action_feedback"
const MALFORMED_SLOT := "scenario_malformed_feedback"
const JOURNAL_FIELDS := ["scenario_id", "status", "phase_id", "last_feedback", "resolved_outcomes", "resolved_branches", "objective_progress", "branch_resolution_records", "command_receipts", "command_receipt_records", "command_results", "fact_receipt_records", "cleanup_receipt_records", "event_correlations", "event_request_history", "local_state"]

class CompactPresentationControl:
	extends "res://scripts/ui/foundation_main.gd"
	func _record_scenario_action_feedback(_command_result: Dictionary, _message: String) -> bool:
		return false

func _run() -> void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-"), "explicit private scenario feedback root required"):
		_finish(); return
	var mode := OS.get_environment("BTH_SCENARIO_FEEDBACK_CASE")
	if not _check(mode in ["prospective", "compact_control", "prospective_restore", "malformed_restore", "legacy"], "explicit prospective/control/cold/malformed/legacy case required"):
		_finish(); return
	if mode not in ["prospective_restore", "malformed_restore"]: _install(OS.get_environment("BTH_CAPTURED_FIXTURE"))
	var slot := MALFORMED_SLOT if mode == "malformed_restore" else "foundation_ui_autosave"
	var baseline: RunState = SaveService.new().load_run(slot)
	if not _check(baseline != null, "official copied save loads without authority replacement"):
		_finish(); return
	var protected := _feedback_gameplay(baseline)
	root.size = Vector2i(1280, 720)
	var app: Host = CompactPresentationControl.new() if mode == "compact_control" else Host.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	for frame in range(3): await process_frame
	app.autosave_slot_id = slot
	if not _check(app.load_foundation_run(), "ordinary native Continue publishes the copied room"):
		app.queue_free(); await process_frame; _finish(); return
	app.set_process(false)
	_check(_feedback_gameplay(app.run_state) == protected, "Continue preserves all original paid history, debt, funds, inventory and RNG")
	_check(app.run_state.bankroll == 71 and app.run_state.grand_casino_chips == 165 and app.run_state.suspicion.level == 0, "captured wallet71/chips165/Heat0 identity")
	_check(str(app.run_state.current_environment.get("scenario_id", "")) == "grand_casino_gala_night", "same Gala owner remains installed")
	if mode in ["prospective", "compact_control"]:
		var initial_owner: Dictionary = app.run_state.current_environment.get("scenario_sequence_state", {})
		if not _check(str(initial_owner.get("phase_id", "")) == "work_1" and initial_owner.get("command_receipts", []).size() == 1 and app.run_state.story_log.size() == 75, "genuine pending source has exactly one prior coat command and75 story rows"):
			app.queue_free(); await process_frame; _finish(); return
		var original_story: Array = app.run_state.story_log.duplicate(true)
		var verified := await _visible_action_once(app, "verify_charity_badge")
		if not verified:
			app.queue_free(); await process_frame; _finish(); return
		_check(_feedback_row_count(app.run_state) == (0 if mode == "compact_control" else 1), "one new Verify acknowledgement, or none in presentation-disabled control")
		var failed_credentials := await _visible_action_once(app, "fail_gala_credentials")
		if not failed_credentials:
			app.queue_free(); await process_frame; _finish(); return
		var owner: Dictionary = app.run_state.current_environment.get("scenario_sequence_state", {})
		_check(str(owner.get("phase_id", "")) == "terminal_failure" and owner.get("resolved_outcomes", []) == ["credential_failed"] and owner.get("command_receipts", []).size() == 3, "exactly two new choices reach the corrected credential-failed aftermath")
		_check(str(owner.get("objective_progress", {}).get("main_task", {}).get("outcome", "")) == "failure", "failure objective agrees with the accepted terminal owner")
		if mode == "compact_control":
			_check(_feedback_row_count(app.run_state) == 0 and app.run_state.story_log.slice(0, 75) == original_story, "control retains existing Core consequences without presentation receipts")
			_check(app.run_state.bankroll == 71 and app.run_state.grand_casino_chips == 165 and app.run_state.suspicion.level == 0, "compact control retains known zero-cost scenario finances")
			facts["control_gameplay"] = _feedback_gameplay(app.run_state)
			facts["control_story_count"] = app.run_state.story_log.size()
			facts["control_journal"] = _journal(app.run_state)
			facts["control_journal_fingerprint"] = Fingerprint.canonical_fingerprint(_journal(app.run_state))
			facts["fidelity"] = "Synthetic presentation-disabled control on a genuine pending private copy, using the actual compact UI handler and visible authority. Only the new informational writer is disabled; Core turns/consequences are unchanged. No historical outcome or reward replay."
			app.save_service.wait_for_async_save(); app.queue_free(); await process_frame; _finish(); return
		var expected_story_count := 77
		if OS.get_environment("BTH_SCENARIO_FEEDBACK_PATH") == "compact":
			var control: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BTH_SCENARIO_FEEDBACK_CONTROL")))
			if not _check(control.get("failures", ["missing"]).is_empty() and control.get("facts", {}).has("control_gameplay"), "matched compact presentation-disabled control is qualified"):
				app.queue_free(); await process_frame; _finish(); return
			protected = control.facts.control_gameplay
			expected_story_count = int(control.facts.control_story_count) + 2
			_check(Fingerprint.canonical_fingerprint(_journal(app.run_state)) == str(control.facts.get("control_journal_fingerprint", "")), "compact producer preserves the canonical control command journal and Core consequences")
		_check(app.run_state.story_log.size() == expected_story_count and _feedback_row_count(app.run_state) == 2 and app.run_state.story_log.slice(0, 75) == original_story, "two new informational rows preserve original history and ordinary consequence rows")
		_check(_feedback_gameplay(app.run_state) == protected, "Verify/Fail presentation adds no financial, paid-state, debt or RNG mutation")
		if _check(not app.run_state.story_log.is_empty() and str(app.run_state.story_log.back().get("type", "")) == "scenario_action_feedback", "new final story row has the proposed scenario feedback contract"):
			_reader_and_replay_contract(app, app.run_state.story_log.back().duplicate(true))
		var accepted_journal := _journal(app.run_state)
		app.save_foundation_run(); app.save_service.wait_for_async_save()
		_check(app.return_to_main_menu(), "normal Menu after private Save")
		app.save_service = SaveService.new()
		app._show_environment_action_acknowledgement("Synthetic stale UI acknowledgement from before loading.")
		if _check(app.load_foundation_run(), "fresh-service ordinary Continue of the new acknowledgement"):
			app.set_process(false)
			_check(_feedback_gameplay(app.run_state) == protected and _journal(app.run_state) == accepted_journal, "Save/Continue preserves accepted command journals and protected gameplay")
			_assert_saved_scenario_view(app)
			_prepare_malformed_cold_copy(app, protected)
	elif mode == "prospective_restore":
		_check(_feedback_row_count(app.run_state) == 2 and _journal(app.run_state).get("command_receipts", []).size() == 3, "independent process reads the exact new two-command saved copy")
		_assert_saved_scenario_view(app)
	elif mode == "malformed_restore":
		_check(_feedback_row_count(app.run_state) == 3 and _journal(app.run_state).get("command_receipts", []).size() == 3, "independent process reads synthetic unsupported-schema tail without new accepted commands")
		var malformed_view := _read_bound_view(app)
		var malformed_text := str(malformed_view.get("text", ""))
		_check(malformed_text.contains("Blackjack +20") and not malformed_text.contains("Fail Gala Credentials") and not malformed_text.contains("Unsupported synthetic"), "cold unsupported final receipt retains the existing game fallback and never scans back to an older scenario row")
		facts["synthetic_cold_limit"] = "Only the additional final informational row has an unsupported schema. It is a negative reader fixture in a separate private slot, not a migrated or accepted Gala outcome."
	else:
		var legacy_before := Fingerprint.canonical_fingerprint(app.run_state.to_save_snapshot())
		var owner_before := _journal(app.run_state)
		_check(str(owner_before.get("phase_id", "")) == "terminal_failure" and owner_before.get("command_receipts", []).size() == 3 and app.run_state.story_log.size() == 75, "genuine completed b7 legacy state has no new presentation row")
		var view := _read_bound_view(app)
		_check(str(view.get("text", "")).contains("Blackjack +20"), "legacy display remains the recorded fallback; no retrospective acknowledgement is invented")
		_check(Fingerprint.canonical_fingerprint(app.run_state.to_save_snapshot()) == legacy_before and _journal(app.run_state) == owner_before, "legacy readers preserve the entire saved state and accepted owner journals")
		facts["legacy_limit"] = "No globally ordered presentation witness exists in the historical b7 save; it is deliberately not migrated or reconstructed."
	_check(_feedback_gameplay(app.run_state) == protected, "all scenario feedback checks preserve original gameplay")
	_check(bool(app.run_state.validate_room_action_authority().get("ok", false)), "strict room authority remains valid")
	facts["mode"] = mode
	facts["dispatch"] = OS.get_environment("BTH_SCENARIO_FEEDBACK_PATH")
	facts["protected"] = protected
	facts["journal"] = _journal(app.run_state)
	facts["test_sha256"] = FileAccess.get_sha256("res://scripts/tests/scenario_action_cold_result_feedback_check.gd")
	facts["fidelity"] = "Genuine copied pending Gala state; two visible Host UI choices (Verify then Fail) only in prospective mode. Separate completed-save and independent-process reader modes. Controlled native observation with ordinary environment clock disabled; not real-time browser acceptance. No historical command/reward replay."
	app.save_service.wait_for_async_save()
	app.queue_free(); await process_frame; _finish()

func _visible_action_once(app: Host, action_id: String) -> bool:
	var chosen_object: Dictionary = {}
	var chosen_action: Dictionary = {}
	var compact := OS.get_environment("BTH_SCENARIO_FEEDBACK_PATH") == "compact"
	for object_value in app._interactable_object_view_list():
		var object_data: Dictionary = object_value
		for action_value in object_data.get("inline_actions" if compact else "scenario_sequence_actions", []):
			var action: Dictionary = action_value
			if str(action.get("id", "")) == action_id and bool(action.get("enabled", true)) and not bool(action.get("disabled", false)):
				if not _check(chosen_action.is_empty(), "visible authored command has one unambiguous current descriptor: " + action_id): return false
				chosen_object = object_data.duplicate(true); chosen_action = action.duplicate(true)
	if not _check(not chosen_action.is_empty(), "current visible authored action exists: " + action_id): return false
	var accepted_before: int = _journal(app.run_state).get("command_receipts", []).size()
	var accepted := false
	if compact:
		accepted = app._activate_scenario_action(
			str(chosen_action.get("scenario_owner_namespace", chosen_object.get("scenario_owner_namespace", "scenario"))),
			str(chosen_action.get("scenario_stable_object_id", chosen_object.get("scenario_stable_object_id", ""))),
			action_id,
			str(chosen_action.get("scenario_idempotency_key", "")),
			str(chosen_action.get("action_origin_owner_namespace", chosen_object.get("owner_namespace", ""))),
			str(chosen_action.get("action_origin_stable_object_id", chosen_object.get("stable_object_id", ""))),
			str(chosen_action.get("action_origin_receipt_key", "")),
			str(chosen_action.get("action_origin_boundary_id", "")),
			str(chosen_action.get("action_origin_fingerprint", ""))
		)
	else:
		accepted = app._activate_scenario_sequence_action(chosen_object, chosen_action)
	if not _check(accepted, "ordinary Host " + ("compact" if compact else "deferred") + " callback accepts " + action_id): return false
	for frame in range(6): await process_frame
	if not facts.has("callback_diagnostics"): facts["callback_diagnostics"] = []
	facts.callback_diagnostics.append({"action_id": action_id, "dispatch": "compact" if compact else "deferred", "pending": app.scenario_sequence_action_pending, "before_commands": accepted_before, "after_commands": _journal(app.run_state).get("command_receipts", []).size(), "phase": _journal(app.run_state).get("phase_id"), "message": app.message_label.text if app.message_label != null else "", "object": chosen_object, "action": chosen_action})
	if not _check(not app.scenario_sequence_action_pending and _journal(app.run_state).get("command_receipts", []).size() == accepted_before + 1, "deferred normal callback commits exactly one new command: " + action_id): return false
	var view := _read_bound_view(app)
	if compact:
		var row: Dictionary = app.run_state.story_log.back()
		if OS.get_environment("BTH_SCENARIO_FEEDBACK_CASE") == "compact_control":
			_check(not str(view.get("text", "")).is_empty() and not str(view.get("text", "")).contains("Blackjack"), "compact control retains its existing warm public acknowledgement")
		else:
			_check(str(row.get("command_id", "")) == action_id and str(view.get("text", "")).contains(str(row.get("message", ""))), "compact Result and receipt retain the exact existing public acknowledgement")
	else:
		_check(str(view.get("text", "")).contains(str(chosen_action.get("label", action_id))), "warm Result acknowledges the actual visible command label")
	return true

func _assert_saved_scenario_view(app: Host) -> void:
	var view := _read_bound_view(app)
	var result: Dictionary = view.get("result", {})
	_check(app.immediate_environment_acknowledgement.is_empty() and not str(view.get("text", "")).contains("Synthetic stale"), "load discards pre-load transient UI feedback")
	var expected_text := "badge" if OS.get_environment("BTH_SCENARIO_FEEDBACK_PATH") == "compact" else "Fail Gala Credentials"
	_check(str(view.get("text", "")).contains(expected_text) and not str(view.get("text", "")).contains("Blackjack"), "cold Result shows the newly accepted public acknowledgement rather than older Blackjack")
	_check(str(view.get("text", "")).contains(str(app.run_state.story_log.back().get("message", ""))), "cold Label retains the exact recorded public acknowledgement")
	_check(str(result.get("summary_source", "")) == "saved_scenario_action_feedback", "cold Result identifies its versioned scenario presentation source")
	for key in ["bankroll_delta", "chips_delta", "suspicion_delta"]:
		_check(int(result.get(key, 0)) == 0, "saved acknowledgement claims no additional " + key)

func _read_bound_view(app: Host) -> Dictionary:
	var before := Fingerprint.canonical_fingerprint(app.run_state.to_save_snapshot())
	var view: Dictionary = app._environment_result_feedback_view()
	app._refresh_environment_result_feedback()
	_check(app.environment_result_body_label.text == str(view.get("text", "")), "actual Result Label is bound to the selected acknowledgement")
	_check(Fingerprint.canonical_fingerprint(app.run_state.to_save_snapshot()) == before, "Result projection and Label binding are full-state read-only")
	facts["last_view_text"] = str(view.get("text", ""))
	return view

func _reader_and_replay_contract(app: Host, row: Dictionary) -> void:
	if not _check(app.has_method(SCENARIO_READER) and app.has_method(SCENARIO_WRITER), "proposed prospective feedback producer/reader exist"):
		return
	_check(str(row.get("feedback_schema", "")) == "bth.scenario_action_feedback/v1", "new acknowledgement is versioned")
	for key in ["bankroll_delta", "chips_delta", "suspicion_delta"]:
		_check(int(row.get(key, 0)) == 0, "informational story row has zero " + key)
	var newest: Dictionary = app.call(SCENARIO_READER, [row])
	_check(not newest.is_empty() and str(newest.get("message", "")) == str(row.get("message", "")), "newest exact acknowledgement restores its existing public text")
	var reader_before := Fingerprint.canonical_fingerprint(app.run_state.to_save_snapshot())
	var zero_floats := row.duplicate(true)
	for key in ["bankroll_delta", "chips_delta", "suspicion_delta"]: zero_floats[key] = 0.0
	_check(not (app.call(SCENARIO_READER, [zero_floats]) as Dictionary).is_empty(), "ordinary numeric-zero JSON roundtrip remains eligible")
	var mismatched_identity := row.duplicate(true); mismatched_identity["feedback_id"] = "synthetic conflicting identity"
	_assert_reader_rejects(app, [mismatched_identity], "feedback identity must match its exact scenario/node/visit/command/receipt tuple")
	var extra_fields := row.duplicate(true)
	extra_fields["currency"] = "synthetic_untrusted_currency"
	extra_fields["private_handler_state"] = {"unrelated": "synthetic"}
	var allowlisted: Dictionary = app.call(SCENARIO_READER, [extra_fields])
	_check(str(allowlisted.get("currency", "")) != "synthetic_untrusted_currency" and not allowlisted.has("private_handler_state"), "only existing public text and neutral fields enter the restored Result")
	for invalid_tail in [null, false, 1, "untyped feedback", [], {}]:
		_assert_reader_rejects(app, [row, invalid_tail], "an untyped final entry never revives an earlier acknowledgement")
	_assert_reader_rejects(app, [], "empty history has no inferred scenario result")
	for field in ["feedback_schema", "feedback_id", "command_receipt_id", "command_id", "scenario_id", "node_id", "environment_visit_id", "message"]:
		var missing := row.duplicate(true); missing.erase(field)
		_assert_reader_rejects(app, [missing], "required field must be recorded: " + field)
		for invalid_value in ["", "   ", null, 42, [], {}]:
			var malformed_identity := row.duplicate(true); malformed_identity[field] = invalid_value
			_assert_reader_rejects(app, [malformed_identity], "invalid field is rejected without string coercion: " + field)
	var wrong_type := row.duplicate(true); wrong_type["type"] = "game_action"
	_assert_reader_rejects(app, [wrong_type], "a different record type is not a scenario acknowledgement")
	for later in [{"type": "event", "message": "Later event."}, {"type": "game_action", "game_id": "blackjack", "message": "Later game."}, {"type": "debt_interest", "message": "Later interest."}]:
		var selected: Dictionary = app.call(SCENARIO_READER, [row, later])
		_check(selected.is_empty(), "earlier scenario acknowledgement never overrides a later " + str(later.type))
	for key in ["bankroll_delta", "chips_delta", "suspicion_delta"]:
		for value in [1, -1, "not numeric", [], {}]:
			var malformed := row.duplicate(true); malformed[key] = value
			_assert_reader_rejects(app, [malformed], "scenario reader rejects nonzero or nonnumeric " + key)
	var unsupported := row.duplicate(true); unsupported["feedback_schema"] = "bth.scenario_action_feedback/future"
	_check((app.call(SCENARIO_READER, [unsupported]) as Dictionary).is_empty(), "unsupported future schema never fabricates a result")
	_assert_reader_rejects(app, [row, unsupported], "unsupported final row cannot revive a previous valid scenario row")
	_check(Fingerprint.canonical_fingerprint(app.run_state.to_save_snapshot()) == reader_before, "all valid, malformed and ordering readers preserve the full genuine state")
	var writer := Host.new(); writer.run_state = RunState.new(); writer.run_state.start_new("SCENARIO-FEEDBACK-RECEIPT-CONTROL")
	writer.run_state.current_environment["environment_visit_id"] = str(row.get("environment_visit_id", ""))
	writer.run_state.log_story(row.duplicate(true))
	var before := Fingerprint.canonical_fingerprint(writer.run_state.to_save_snapshot())
	var receipt := {"receipt_id": row.get("command_receipt_id", ""), "command_id": row.get("command_id", ""), "scenario_id": row.get("scenario_id", ""), "node_id": row.get("node_id", ""), "replayed": false}
	_check(not bool(writer.call(SCENARIO_WRITER, {"ok": true, "replayed": false, "result_receipt": receipt}, str(row.get("message", "")))), "same retained receipt cannot append another acknowledgement")
	for result in [{"ok": false, "result_receipt": receipt}, {"ok": "true", "result_receipt": receipt}, {"ok": true, "replayed": true, "result_receipt": receipt}, {"ok": true, "replayed": "false", "result_receipt": receipt}, {"ok": true, "result_receipt": {}}, {"ok": true, "result_receipt": []}]:
		_check(not bool(writer.call(SCENARIO_WRITER, result, "Synthetic rejected receipt.")), "rejected/replayed/missing-identity command cannot create a new ordering witness")
	var replayed_receipt := receipt.duplicate(true); replayed_receipt["replayed"] = true
	_check(not bool(writer.call(SCENARIO_WRITER, {"ok": true, "result_receipt": replayed_receipt}, "Synthetic replayed receipt.")), "a replay flag inside the authoritative result receipt cannot stamp")
	for blank_message in ["", "   "]:
		_check(not bool(writer.call(SCENARIO_WRITER, {"ok": true, "result_receipt": receipt}, blank_message)), "empty public acknowledgement cannot stamp")
	for field in ["receipt_id", "command_id", "scenario_id", "node_id"]:
		var missing_receipt := receipt.duplicate(true); missing_receipt.erase(field)
		_check(not bool(writer.call(SCENARIO_WRITER, {"ok": true, "result_receipt": missing_receipt}, "Synthetic missing identity.")), "producer rejects missing authoritative " + field)
		for invalid_value in ["   ", 42, [], {}]:
			var malformed_receipt := receipt.duplicate(true); malformed_receipt[field] = invalid_value
			_check(not bool(writer.call(SCENARIO_WRITER, {"ok": true, "result_receipt": malformed_receipt}, "Synthetic malformed identity.")), "producer rejects malformed authoritative " + field)
	_check(Fingerprint.canonical_fingerprint(writer.run_state.to_save_snapshot()) == before, "duplicate/rejected/replayed producer controls do not mutate even the synthetic full state")
	writer._record_world_sequence_outcome_feedback("synthetic-owner", "synthetic-delivery", "Later committed delivery.")
	var crew_row: Dictionary = writer.run_state.story_log.back().duplicate(true)
	_check((app.call(SCENARIO_READER, [row, crew_row]) as Dictionary).is_empty(), "later Crew v1 row wins over scenario feedback")
	_check(not app._saved_world_sequence_feedback_from_story_log([row, crew_row]).is_empty(), "existing Crew reader contract remains usable")
	_check(app._saved_world_sequence_feedback_from_story_log([crew_row, row]).is_empty() and not (app.call(SCENARIO_READER, [crew_row, row]) as Dictionary).is_empty(), "newer scenario row wins while Crew refuses to revive older history")
	writer.free()

func _assert_reader_rejects(app: Host, entries: Array, label: String) -> void:
	var selected: Dictionary = app.call(SCENARIO_READER, entries)
	_check(selected.is_empty(), label)

func _prepare_malformed_cold_copy(app: Host, expected: Dictionary) -> void:
	# This is explicitly synthetic negative presentation data. The genuine
	# prospective slot and all original save/profile files remain untouched.
	var original := Fingerprint.canonical_fingerprint(app.run_state.to_save_snapshot())
	var clone := RunState.new(); clone.from_dict(app.run_state.to_save_snapshot())
	if not _check(not clone.story_log.is_empty() and str(clone.story_log.back().get("type", "")) == "scenario_action_feedback", "malformed cold fixture requires an existing new acknowledgement"):
		return
	var unsupported: Dictionary = clone.story_log.back().duplicate(true)
	unsupported["feedback_schema"] = "bth.scenario_action_feedback/future"
	unsupported["message"] = "Unsupported synthetic acknowledgement must not be shown."
	clone.story_log.append(unsupported)
	_check(clone.story_log.size() == app.run_state.story_log.size() + 1 and _feedback_gameplay(clone) == expected and _journal(clone) == _journal(app.run_state), "synthetic unsupported tail changes only private informational history")
	_check(app.save_service.save_run(clone, MALFORMED_SLOT) == OK, "official Save writes separate unsupported-schema cold fixture")
	_check(Fingerprint.canonical_fingerprint(app.run_state.to_save_snapshot()) == original, "negative fixture creation leaves the genuine prospective run fully unchanged")

func _journal(run: RunState) -> Dictionary:
	var state: Dictionary = run.current_environment.get("scenario_sequence_state", {})
	var selected: Dictionary = {}
	for key in JOURNAL_FIELDS: selected[str(key)] = state.get(key)
	return selected.duplicate(true)

func _feedback_row_count(run: RunState) -> int:
	var count := 0
	for row in run.story_log:
		if str(row.get("type", "")) == "scenario_action_feedback": count += 1
	return count

func _feedback_gameplay(run: RunState) -> Dictionary:
	var source := run.to_save_snapshot()
	var original_rows: Array = []
	for row in run.story_log:
		if str(row.get("type", "")) != "scenario_action_feedback": original_rows.append(row)
	var result: Dictionary = {}
	for key in ["bankroll", "grand_casino_chips", "suspicion", "debt", "grand_casino_atm_debt", "inventory", "rng_seed", "rng_state", "crew_state", "numbers_state", "home_state", "active_delivery_run", "run_status", "run_spending_score", "story_money_archive"]:
		result[str(key)] = Fingerprint.canonical_fingerprint(source.get(key))
	result["original_story"] = Fingerprint.canonical_fingerprint(original_rows)
	result["paid_game_states"] = Fingerprint.canonical_fingerprint(run.current_environment.get("game_states", {}))
	return result
