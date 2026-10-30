extends "res://scripts/tests/scenario_venue_cycle_captured_check.gd"

const Fingerprint := preload("res://scripts/core/game_ritual_runtime.gd")
const PROSPECTIVE_SLOT := "crew_prospective_feedback"

# Synthetic owner protocol only; this stub never pays or resolves a real job.
class ConsumedOutcomeStub:
	extends RunState
	var pending := true
	var consume_calls := 0
	var accept_consume := true
	func world_sequence_pending_outcomes(_token: String) -> Array:
		return [{"channel_id": "delivery_handoff", "receipt_id": "synthetic-receipt"}] if pending else []
	func world_sequence_consume_delivery_outcome(_token: String, _receipt_id: String, _node_id: String = "") -> Dictionary:
		if not accept_consume: return {"ok": false, "errors": ["Synthetic rejected consume."]}
		pending = false
		consume_calls += 1
		return {"ok": true, "message": "Synthetic committed delivery outcome."}

func _run() -> void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-"), "explicit private Crew result root required"):
		_finish(); return
	_producer_contract()
	var mode := OS.get_environment("BTH_CREW_COLD_RESULT_CASE")
	if not _check(mode in ["before_handoff", "after_handoff", "prospective_restore"], "explicit captured or prospective case required"):
		_finish(); return
	if mode != "prospective_restore": _install(OS.get_environment("BTH_CAPTURED_FIXTURE"))
	var slot := PROSPECTIVE_SLOT if mode == "prospective_restore" else "foundation_ui_autosave"
	var reference: Variant = SaveService.new().load_run(slot)
	if not _check(reference is RunState, "official private save loads with unchanged authority"):
		_finish(); return
	var expected := _feedback_protected(reference)
	var is_after := mode != "before_handoff"
	_check(reference.bankroll == (93 if is_after else 71) and reference.grand_casino_chips == 0, "genuine branch wallet identity")
	_check(reference.crew_reputation() == (53 if is_after else 32) and reference.crew_delivery_obligation_count() == (1 if is_after else 2), "genuine branch Crew/duties identity")
	root.size = Vector2i(1280, 720)
	var app := Host.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	for frame in range(3): await process_frame
	app.autosave_slot_id = slot
	if not _check(app.load_foundation_run(), "normal native cold Continue without a gameplay choice"):
		app.queue_free(); await process_frame; _finish(); return
	app.set_process(false)
	_check(_feedback_protected(app.run_state) == expected, "Continue preserves paid history, delivery, money, debt and RNG")
	var view := _read_view(app)
	if mode == "prospective_restore":
		_assert_prospective_view(app, view)
	else:
		_check(app.run_state.story_log.size() == 19 and str(app.run_state.story_log.back().get("event_id", "")) == "machine_jam", "legacy captured history is never rewritten")
		_check(str(view.get("text", "")).contains("Play stops. Attention moves on."), "legacy ordering absence keeps existing fallback rather than inventing a recent handoff")
		_check(int(view.get("result", {}).get("bankroll_delta", 0)) == -3 and int(view.get("result", {}).get("suspicion_delta", 0)) == -3, "unchanged legacy recorded event retains its original deltas")
		if is_after:
			_check(str(app.run_state.active_delivery_run.get("status", "")) == "resolved" and bool(app.run_state.active_delivery_run.get("world_applied", false)), "legacy handoff is already committed")
			facts["legacy_limit"] = "The completed20fc save has no ordered feedback row. Its last-event fallback remains unchanged; no historical recency or applied22 is inferred."
			await _prospective_saved_copy(app, expected)
		else:
			_check(str(app.run_state.active_delivery_run.get("status", "")) == "active", "before-handoff delivery is still active")
	_check(_feedback_protected(app.run_state) == expected, "all observation and prospective presentation leave gameplay unchanged")
	facts["case"] = mode
	facts["protected"] = expected
	facts["test_sha256"] = FileAccess.get_sha256("res://scripts/tests/crew_handoff_cold_result_feedback_check.gd")
	facts["fidelity"] = "Genuine copied saves inspected without event/handoff/game input. Synthetic owner protocol tests production consume integration; a clearly synthetic informational stamp on a clone tests new-receipt Save/Continue. No settlement replay or monetary inference."
	app.save_service.wait_for_async_save()
	app.queue_free(); await process_frame; _finish()

func _producer_contract() -> void:
	var run := ConsumedOutcomeStub.new()
	run.start_new("CREW-FEEDBACK-PRESENTATION-ONLY")
	var host := Host.new(); host.run_state = run
	var before := _feedback_protected(run)
	var count := run.story_log.size()
	var first: Dictionary = host._consume_world_sequence_outcomes("synthetic-owner")
	if not _check(bool(first.get("ok", false)) and run.consume_calls == 1 and run.story_log.size() == count + 1, "actual UI consume integration records one acknowledgement after synthetic committed consume"):
		host.free(); return
	var row: Dictionary = run.story_log.back().duplicate(true)
	_check(str(row.get("feedback_schema", "")) == "bth.world_sequence_feedback/v1" and int(row.get("bankroll_delta", 999)) == 0 and int(row.get("suspicion_delta", 999)) == 0, "receipt is versioned and informational only")
	_check(_feedback_protected(run) == before, "producer does not pay, change debt/paid history/RNG or alter delivery authority")
	var second: Dictionary = host._consume_world_sequence_outcomes("synthetic-owner")
	_check(bool(second.get("inactive", false)) and run.consume_calls == 1 and run.story_log.size() == count + 1, "consumed owner cannot stamp or settle a second time")
	_check(not host._record_world_sequence_outcome_feedback("synthetic-owner", "synthetic-receipt", "Synthetic committed delivery outcome.") and run.story_log.size() == count + 1, "duplicate retained receipt identity is not appended again")
	var feedback: Dictionary = host._saved_world_sequence_feedback_from_story_log([row])
	_check(str(feedback.get("message", "")) == "Synthetic committed delivery outcome." and int(feedback.get("bankroll_delta", 999)) == 0, "newest recorded public text restores without a second money delta")
	for later in [{"type": "event", "message": "Later event."}, {"type": "game_action", "game_id": "blackjack", "message": "Later game."}, {"type": "debt_interest", "message": "Later interest."}]:
		_check(host._saved_world_sequence_feedback_from_story_log([row, later]).is_empty(), "no earlier receipt overrides a later durable " + str(later.type))
	var malformed := row.duplicate(true); malformed["bankroll_delta"] = 22
	_check(host._saved_world_sequence_feedback_from_story_log([malformed]).is_empty(), "informational receipt cannot restore a financial instruction")
	_check(host._saved_world_sequence_feedback_from_story_log([{"type": "event", "message": "Legacy event."}]).is_empty(), "missing versioned ordering witness never triggers legacy inference")
	_check(_feedback_protected(run) == before, "all reader controls preserve gameplay state")
	var rejected := ConsumedOutcomeStub.new(); rejected.start_new("CREW-FEEDBACK-REJECTED")
	rejected.accept_consume = false; host.run_state = rejected
	var rejected_before := _feedback_protected(rejected)
	var rejected_count := rejected.story_log.size()
	var failure: Dictionary = host._consume_world_sequence_outcomes("synthetic-owner")
	_check(not bool(failure.get("ok", false)) and rejected.story_log.size() == rejected_count and _feedback_protected(rejected) == rejected_before, "rejected Core consume creates no success stamp or gameplay change")
	host.free()

func _prospective_saved_copy(app: Host, expected: Dictionary) -> void:
	var clone := RunState.new(); clone.from_dict(app.run_state.to_save_snapshot())
	var checkpoint: Dictionary = clone.active_delivery_run.get("closed_checkpoint", {})
	var public_result: Dictionary = checkpoint.get("public_result", {})
	_check(bool(public_result.get("ok", false)) and bool(public_result.get("resolved", false)), "genuine closed checkpoint has its generic public completion")
	var writer := Host.new(); writer.run_state = clone
	_check(writer._record_world_sequence_outcome_feedback(str(checkpoint.get("owner_token", "")), str(checkpoint.get("outcome_receipt_id", "")), str(public_result.get("message", ""))), "synthetic prospective display fixture stamps existing public text only")
	_check(clone.story_log.size() == 20 and _feedback_protected(clone) == expected, "only one informational row is added to the cloned fixture")
	writer.free()
	app.save_service.wait_for_async_save()
	if not _check(app.save_service.save_run(clone, PROSPECTIVE_SLOT) == OK, "official Save accepts prospective informational receipt with unchanged paid authority"):
		return
	_check(app.return_to_main_menu(), "normal private Main Menu before prospective Continue")
	app.autosave_slot_id = PROSPECTIVE_SLOT
	app.save_service = SaveService.new()
	if _check(app.load_foundation_run(), "normal fresh-service Continue of prospective presentation-only fixture"):
		_check(_feedback_protected(app.run_state) == expected and app.run_state.story_log.size() == 20, "new receipt survives Save/Continue without an extra story or settlement")
		_assert_prospective_view(app, _read_view(app))

func _read_view(app: Host) -> Dictionary:
	var before := Fingerprint.canonical_fingerprint(app.run_state.to_save_snapshot())
	var view: Dictionary = app._environment_result_feedback_view()
	app._refresh_environment_result_feedback()
	_check(Fingerprint.canonical_fingerprint(app.run_state.to_save_snapshot()) == before, "feedback projection and Label binding preserve the full saved state")
	_check(app.environment_result_body_label.text == str(view.get("text", "")), "actual Result Label receives selected text")
	facts["last_view_text"] = str(view.get("text", ""))
	return view

func _assert_prospective_view(app: Host, view: Dictionary) -> void:
	var result: Dictionary = view.get("result", {})
	_check(str(view.get("text", "")).to_lower().contains("package changes hands") and not str(view.get("text", "")).contains("Play stops. Attention moves on."), "new ordered receipt replaces the previous Machine Jam after cold Continue")
	_check(str(result.get("summary_source", "")) == "saved_world_sequence_feedback" and int(result.get("bankroll_delta", 999)) == 0 and int(result.get("suspicion_delta", 999)) == 0, "restored acknowledgement claims no unrecorded payment or Heat")
	_check(app.run_state.bankroll == 93 and app.run_state.crew_delivery_obligation_count() == 1, "same actual cash93 and one duty after display restore")

func _feedback_protected(run: RunState) -> Dictionary:
	var source := run.to_save_snapshot()
	var original_rows: Array = []
	for row in run.story_log:
		if str(row.get("type", "")) != "world_sequence_feedback": original_rows.append(row)
	return {"cash": run.bankroll, "chips": run.grand_casino_chips, "debt_sha256": Fingerprint.canonical_fingerprint(run.debt), "rng_sha256": Fingerprint.canonical_fingerprint(run.rng_state), "crew_sha256": Fingerprint.canonical_fingerprint(source.get("crew_state", {})), "original_story_sha256": Fingerprint.canonical_fingerprint(original_rows), "delivery_sha256": Fingerprint.canonical_fingerprint(run.active_delivery_run), "inventory_sha256": Fingerprint.canonical_fingerprint(run.inventory), "action_index": run.numbers_state.action_index}
