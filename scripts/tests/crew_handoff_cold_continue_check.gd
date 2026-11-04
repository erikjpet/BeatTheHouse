extends "res://scripts/tests/crew_expired_handoff_check.gd"

# Read only the five authentic slots saved by the separate `all` fixture process.
# This adds process-cold coverage without regenerating or editing saved state.
func _run() -> void:
	if OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").is_empty():
		push_error("crew_handoff_cold_continue_check requires isolated fixture storage")
		quit(64)
		return
	library = ContentLibrary.new()
	library.load(false)
	var layout_root: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/environments/scenario_slot_layouts.json"))
	for layout_value in layout_root.get("layouts", []):
		var layout: Dictionary = layout_value
		action_only_visual_ids["%s::%s" % [str(layout.get("map_id", "")), str(layout.get("scenario_id", ""))]] = layout.get("audit", {}).get("action_only_ids", [])
	for slot in ["crew_expired_handoff_arrival_0", "crew_expired_handoff_arrival_1", "crew_expired_handoff_mounted", "crew_expired_handoff_success_open", "crew_expired_handoff_success"]:
		var loaded: Variant = SaveService.new().load_run(slot)
		_check(loaded is RunState, "Process-cold fixture could not load authentic slot %s" % slot)
		if not loaded is RunState:
			continue
		var run: RunState = loaded
		var token := ""
		for value in run.world_sequence_registrations.keys():
			var registration: Dictionary = run.world_sequence_registrations[value]
			if str(registration.get("node_id", "")) == "jazz_club" and str(registration.get("public_instance_token", "")) == str(run.active_delivery_run.get("job_id", "")):
				token = str(value)
		_check(not token.is_empty(), "Process-cold slot lost its delivery owner: %s" % slot)
		var before := _settlement(run)
		var finalized := _finalize_room(run)
		_check(bool(finalized.get("ok", false)), "Process-cold finalization failed: %s" % slot)
		_no_handoff(run, token, "process-cold " + slot)
		_check(_settlement(run) == before, "Process-cold finalization replayed settlement: %s" % slot)
		var resumed := run.world_sequence_resume_delivery_checkpoint()
		_check(bool(resumed.get("ok", false)) and bool(resumed.get("inactive", false)) and _settlement(run) == before, "Process-cold checkpoint replay changed settled state: %s" % slot)
		_check(not run.delivery_has_active_run() and run.world_sequence_pending_outcomes(token).is_empty(), "Process-cold slot reopened a settled handoff: %s" % slot)
		var missed := not str(slot).contains("success")
		_check(_missed_count(run) == (1 if missed else 0), "Process-cold missed-delivery count changed: %s" % slot)
		print("CREW_HANDOFF_PROCESS_COLD ", JSON.stringify({"slot": slot, "missed": _missed_count(run), "cash": run.bankroll, "trust": run.crew_trust("crew_rook"), "owed": run.crew_delivery_obligation_count(), "pending": run.world_sequence_pending_outcomes(token).size(), "checkpoint_inactive": bool(resumed.get("inactive", false))}))
	print("CREW_HANDOFF_PROCESS_COLD_RESULT checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
