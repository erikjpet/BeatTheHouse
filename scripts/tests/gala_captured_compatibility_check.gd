extends "res://scripts/tests/scenario_venue_cycle_captured_check.gd"

const GALA := "grand_casino_gala_night"
const JOURNAL_KEYS := ["status", "phase_id", "seed_token", "last_feedback", "resolved_outcomes", "resolved_branches", "objective_progress", "branch_resolution_records", "command_receipts", "command_receipt_records", "command_results", "fact_receipt_records", "cleanup_receipt_records", "event_correlations", "event_request_history", "local_state", "semantic_state"]

func _run() -> void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-gala-"), "explicit private Gala compatibility root required"): _finish(); return
	var bundle := OS.get_environment("BTH_CAPTURED_FIXTURE")
	var mode := OS.get_environment("BTH_GALA_COMPAT_MODE")
	var raw: Dictionary = _raw_decode(JSON.parse_string(FileAccess.get_file_as_string(bundle.path_join("run-state.json"))))
	var raw_room: Dictionary = raw.get("current_environment", {})
	if raw_room.has("__bth_environment_ref"): raw_room = raw.get("environment_registry", {}).get(raw_room.__bth_environment_ref, {})
	var expected: Dictionary = raw_room.get("scenario_sequence_state", {}).duplicate(true)
	facts = {"mode": mode, "fidelity": "Genuine historical copied save; official Continue/Save and native room reentry only. No accepted command, reward replay, travel, clock manipulation or outcome replacement.", "original_owner": _journal(expected), "package_sha256": FileAccess.get_sha256("res://data/environments/scenario_sequences/env06_7_queen_public.json")}
	if mode != "restore": _install(bundle)
	var service := SaveService.new()
	var baseline: RunState = service.load_run("foundation_ui_autosave")
	if not _check(baseline != null, "official copied historical save loads"): _finish(); return
	var initial: Dictionary = baseline.current_environment.get("scenario_sequence_state", {})
	facts["loaded_owner"] = _journal(initial)
	facts["initial_journal_diff"] = _different_paths(_journal(expected), _journal(initial))
	if not _check(facts.initial_journal_diff.is_empty(), "catalog expansion preserves all recorded owner journals and accepted outcome"):
		_finish(); return
	_check(str(baseline.current_environment.get("scenario_id", "")) == GALA and str(initial.get("scenario_id", "")) == GALA, "same Gala scenario survives catalog expansion")
	_check(baseline.bankroll == 71 and baseline.grand_casino_chips == 165, "original cash71 chips165 remain exact")
	var protected := _protected(baseline)
	facts["resolver_selected_signature"] = baseline.scenario_sequence_definition().get("sequence", {}).get("sequence_signature", "")
	root.size = Vector2i(1280, 720)
	var app := Host.new(); app.continuous_environment_clock_enabled = false; app.script_prewarm_stopping = true
	root.add_child(app)
	for frame in range(3): await process_frame
	if not _check(app.load_foundation_run(), "ordinary historical Host Continue succeeds"):
		app.queue_free(); await process_frame; _finish(); return
	for frame in range(4): await process_frame
	app.set_process(false)
	var run: RunState = app.run_state
	facts["continued_owner"] = _journal(run.current_environment.get("scenario_sequence_state", {}))
	facts["continued_journal_diff"] = _different_paths(_journal(expected), facts.continued_owner)
	_check(facts.continued_journal_diff.is_empty(), "Continue retains historical phase, scenery, feedback and complete accepted journals")
	_check(_different_paths(protected, _protected(run)).is_empty(), "Continue preserves funds, inventory, reward flags, debt, paid games, story and RNG")
	_check(bool(run.validate_room_action_authority().get("ok", false)), "historical published room has strict valid authority")
	facts["catalog_rejection"] = app._interactable_object_view_list().filter(func(row): return str(row.get("object_id", "")) == "room:unavailable")
	facts["definition_keys"] = run.scenario_sequence_definition().keys()
	facts["runtime_errors"] = run.current_environment.get("scenario_sequence_state", {}).get("runtime_errors", [])
	facts["migration_error"] = run.current_environment.get("scenario_sequence_migration_error", "")
	facts["lifecycle_errors"] = run.current_environment.get("scenario_sequence_lifecycle_errors", [])
	var catalog: Dictionary = ScenarioSequenceCatalog.default_catalog_snapshot()
	facts["catalog_status"] = {"ok": catalog.get("ok"), "failures": catalog.get("failures", [])}
	_check(not _has_room_unavailable(app) and not app._interactable_object_view_list().is_empty(), "ordinary historical base-room controls remain usable")
	var reentry: Dictionary = run.scenario_reenter_current("gala-compat:" + mode)
	facts["reentry_result"] = reentry
	_check(bool(reentry.get("ok", false)), "native production scenario reentry accepts historical owner")
	_check(_different_paths(_journal(expected), _journal(run.current_environment.get("scenario_sequence_state", {}))).is_empty(), "reentry retains historical outcome and accepted records without replay")
	_check(_different_paths(protected, _protected(run)).is_empty(), "reentry has no financial/reward/history/RNG effect")
	var corrupted := RunState.new(); corrupted.from_dict(run.to_dict())
	corrupted.current_environment = run.current_environment.duplicate(true)
	var bad_records: Array = corrupted.current_environment.scenario_sequence_state.command_receipt_records.duplicate(true)
	bad_records[0]["fingerprint"] = "0".repeat(64)
	corrupted.current_environment.scenario_sequence_state["command_receipt_records"] = bad_records
	corrupted.current_environment.erase(EngineScript.TRUSTED_STATE_REFERENCE_KEY)
	_check(not bool(corrupted.scenario_finalize_installed_environment(app.library).get("ok", true)), "historical definition selection does not accept a forged command journal")
	var corrected := {"scenario_sequence_state": {"scenario_id": GALA, "status": "aftermath", "phase_id": "terminal_failure", "resolved_outcomes": ["credential_failed"]}}
	_check(EngineScript.recorded_terminal_definition(corrected, {}).is_empty(), "new corrected failure never selects historical content")
	_check(EngineScript.recorded_terminal_definition({"scenario_sequence_state": {"scenario_id": GALA, "status": "active", "phase_id": "work_1"}}, {}).is_empty(), "unfinished Gala uses the corrected current content")
	app.save_foundation_run(); app.save_service.wait_for_async_save()
	var restored: RunState = SaveService.new().load_run("foundation_ui_autosave")
	_check(restored != null, "normal Save and fresh SaveService restore succeed")
	if restored != null:
		facts["restored_journal_diff"] = _different_paths(_journal(run.current_environment.get("scenario_sequence_state", {})), _journal(restored.current_environment.get("scenario_sequence_state", {})))
		_check(facts.restored_journal_diff.is_empty(), "Save restores complete accepted owner journals and original aftermath")
		_check(_different_paths(protected, _protected(restored)).is_empty(), "Save/restore retains all protected gameplay")
	facts["final_owner"] = _journal(run.current_environment.get("scenario_sequence_state", {}))
	app.queue_free(); await process_frame; _finish()

func _journal(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in JOURNAL_KEYS: result[str(key)] = state.get(key)
	return result.duplicate(true)

func _raw_decode(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		if value.size() == 1 and value.has("__bth_exact_int64"): return str(value.__bth_exact_int64).to_int()
		var result: Dictionary = {}
		for key in value: result[key] = _raw_decode(value[key])
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for item in value: result.append(_raw_decode(item))
		return result
	return value

func _different_paths(before: Variant, after: Variant, prefix: String = "") -> Array:
	var result: Array = []
	if typeof(before) == TYPE_DICTIONARY and typeof(after) == TYPE_DICTIONARY:
		for key in before:
			if not after.has(key): result.append({"path": prefix + "/" + str(key), "kind": "missing_key"})
			else: result.append_array(_different_paths(before[key], after[key], prefix + "/" + str(key)))
		for key in after:
			if not before.has(key): result.append({"path": prefix + "/" + str(key), "kind": "new_key"})
	elif typeof(before) == TYPE_ARRAY and typeof(after) == TYPE_ARRAY:
		if before.size() != after.size(): result.append({"path": prefix, "kind": "array_size"})
		else:
			for i in range(before.size()): result.append_array(_different_paths(before[i], after[i], prefix + "/" + str(i)))
	elif typeof(before) in [TYPE_INT, TYPE_FLOAT] and typeof(after) in [TYPE_INT, TYPE_FLOAT]:
		if before != after:
			# Native baseline reproduces three sub1e-15 JSON geometry roundoffs.
			# No other paths, money, receipts, or RNG receive any tolerance.
			var visual := prefix.begins_with("/semantic_state/base_interactions/") and prefix.contains("/normalized_hit_rect/")
			if not (visual and is_finite(float(before)) and is_finite(float(after)) and absf(float(before) - float(after)) <= 0.000000000001):
				result.append({"path": prefix, "before": before, "after": after})
	elif typeof(before) != typeof(after) or before != after:
		result.append({"path": prefix, "before_type": typeof(before), "after_type": typeof(after)})
	return result.slice(0, 30)
