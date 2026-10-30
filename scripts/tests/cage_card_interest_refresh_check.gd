extends "res://scripts/tests/scenario_venue_cycle_captured_check.gd"

const Dock := preload("res://scripts/ui/talk_dock.gd")
const TALK_ID := "dialogue:linda_cage_services"

func _run() -> void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-"), "private Card clock test root required"): _finish(); return
	var mode := OS.get_environment("BTH_CARD_INTEREST_CASE")
	if mode != "restore_only": _install(OS.get_environment("BTH_CAPTURED_FIXTURE"))
	root.size = Vector2i(1280, 720)
	var app := Host.new(); app.continuous_environment_clock_enabled = false; app.script_prewarm_stopping = true
	root.add_child(app)
	for frame in range(3): await process_frame
	if not _check(app.load_foundation_run(), "official private Continue of genuine Card fixture"): app.queue_free(); _finish(); return
	app.set_process(false) # Test drives only the normal owner clock callback below.
	var run: RunState = app.run_state
	facts = {"mode": mode, "test_sha256": FileAccess.get_sha256("res://scripts/tests/cage_card_interest_refresh_check.gd")}
	if mode == "restore_only":
		_check(run.bankroll == 123 and run.grand_casino_chips == 155 and run.grand_casino_atm_debt() == 52, "independent-process interest52 balances persist")
		_check(_interest_count(run) == 1, "independent-process exactly one interest receipt")
		_check(str(run.pending_talk_event(TALK_ID).get("current_node", "")) == "card", "independent-process open Card remains the same page")
		_check(app.talk_dock.full_body_text.contains("$52") and _claim_reason(app).contains("$52") and not bool(_claim_choice(app).get("enabled", true)), "independent-process Card body and disabled Claim both show52")
	else:
		_check(run.bankroll == 123 and run.grand_casino_chips == 155 and run.grand_casino_atm_debt() == 49, "genuine123cash155chips49marker")
		_check(str(run.current_environment.get("archetype_id", "")) == RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID, "genuine Cage, no live table decision")
		if run.pending_talk_event(TALK_ID).is_empty():
			_check(app._start_linda_cage_services({"object_id": "casino_fixture:cage_counter"}), "ordinary Linda service page opens")
		if str(run.pending_talk_event(TALK_ID).get("current_node", "")) != "card":
			app._on_talk_dock_choice_requested(TALK_ID, "open_card")
		_check(str(run.pending_talk_event(TALK_ID).get("current_node", "")) == "card", "normal Card page selected")
		_check(app.talk_dock.full_body_text.contains("$49") and _claim_reason(app).contains("$49"), "actual Card summary and disabled Claim show49 before interest")
		_check(not bool(_claim_choice(app).get("enabled", true)), "positive-marker Claim disabled")
		app.continuous_environment_clock_enabled = true
		_tick_to(app, 3059) # Controlled test minutes; not a real-time Web claim.
		_check(run.grand_casino_atm_debt() == 49 and _interest_count(run) == 0, "02:59 marker49 no early interest")
		_check(app.talk_dock.full_body_text.contains("$49"), "after earlier venue-close refresh Card still49")
		if mode == "closed":
			app._on_talk_dock_choice_requested(TALK_ID, Dock.NEUTRAL_CLOSE_CHOICE_ID)
			_check(run.pending_talk_event(TALK_ID).is_empty() and not app.talk_dock.conversation_active, "neutral Close releases Card page before interest")
		var original_entry := run.pending_talk_event(TALK_ID).duplicate(true)
		var control := RunState.new(); control.from_dict(run.to_dict())
		control.advance_game_clock_minutes(1)
		_tick_to(app, 3060)
		_check(run.grand_casino_atm_debt() == 52 and _interest_count(run) == 1, "03:00 accrues exactly3 once to52")
		_check(_accounting(run) == _accounting(control), "presentation fix equals unchanged clock financial control, full history/games/RNG")
		_check(run.bankroll == 123 and run.grand_casino_chips == 155, "refresh consumes no cash/chips, no repayment")
		if mode == "closed":
			_check(run.pending_talk_event(TALK_ID).is_empty() and not app.talk_dock.conversation_active, "interest never automatically reopens dismissed Card")
		else:
			_check(run.pending_talk_event(TALK_ID) == original_entry, "same dialogue identity/node/queue ownership retained")
			_check(app.talk_dock.full_body_text.contains("$52") and not app.talk_dock.full_body_text.contains("$49"), "already-open actual Card body changes49 to52 without reopening")
			_check(_claim_reason(app).contains("$52") and not bool(_claim_choice(app).get("enabled", true)), "already-open disabled Claim reflects actual52")
		var accounting := _accounting(run)
		var rendered_key: String = app.talk_dock.rendered_entry_key
		_tick_to(app, 3061)
		_check(_accounting(run) == accounting and _interest_count(run) == 1, "next minute does not duplicate interest/gameplay")
		_check(app.talk_dock.rendered_entry_key == rendered_key, "unchanged marker does not rebuild dialogue each minute")
		app.continuous_environment_clock_enabled = false
		app.save_foundation_run(); app.save_service.wait_for_async_save()
		_check(app.return_to_main_menu(), "normal private Save/Main Menu")
		app.save_service = SaveService.new()
		_check(app.load_foundation_run(), "official fresh-service Continue")
		facts["save_continue_accounting_differences"] = _different_paths(accounting, _accounting(app.run_state))
		_check(facts["save_continue_accounting_differences"].is_empty(), "Save/Continue retains one interest and semantically unchanged full money/game history/RNG")
		_check(app.run_state.grand_casino_atm_debt() == 52 and _interest_count(app.run_state) == 1, "persisted52 has one charge")
		if mode == "closed": _check(app.run_state.pending_talk_event(TALK_ID).is_empty(), "cold dismissed Card remains dismissed")
		else: _check(app.talk_dock.full_body_text.contains("$52") and _claim_reason(app).contains("$52"), "cold open Card still shows52")
	facts["cash"] = app.run_state.bankroll; facts["chips"] = app.run_state.grand_casino_chips
	facts["marker"] = app.run_state.grand_casino_atm_debt(); facts["interest_count"] = _interest_count(app.run_state)
	facts["card_body"] = app.talk_dock.full_body_text; facts["claim_reason"] = _claim_reason(app)
	facts["fidelity"] = "Copied genuine fixture; normal owner callback with controlled elapsed minutes, not real-time Web pacing. No wager, repayment or interest rule change. restore_only uses the open-case private saved branch without reinstalling the original."
	app.queue_free(); await process_frame; _finish()

func _tick_to(app: Host, target: int) -> void:
	app.environment_clock_fractional_minutes = 0.0
	app._advance_run_game_clock(float(target - app.run_state.game_clock_minutes) / Host.GAME_CLOCK_MINUTES_PER_REAL_SECOND + 0.000001)
	_check(app.run_state.game_clock_minutes == target, "controlled normal owner clock reaches%d" % target)

func _claim_choice(app: Host) -> Dictionary:
	for row in app.talk_dock.option.get("choices", []):
		if str(row.get("id", "")) == "cage_claim_card": return row
	return {}
func _claim_reason(app: Host) -> String:
	return str(_claim_choice(app).get("disabled_reason", _claim_choice(app).get("text", "")))
func _interest_count(run: RunState) -> int:
	var count := 0
	for row in run.story_log:
		if str(row.get("type", "")) == "debt_interest": count += 1
	return count
func _accounting(run: RunState) -> Dictionary:
	var source := run.to_dict()
	var result: Dictionary = {}
	for key in ["bankroll", "grand_casino_chips", "debt", "story_log", "story_log_archive_count", "story_money_archive", "game_history", "rng_seed", "rng_state", "inventory", "score"]:
		result[key] = source.get(key)
	# Official restore adds exactly this absent legacy default (RunState's
	# _normalize_debt_entries). Preserve every supplied value and every other
	# ledger field; do not normalize amounts, statuses, deadlines or histories.
	result["debt"] = result.get("debt", []).duplicate(true)
	for entry in result["debt"]:
		if not entry.has("default_consequence"): entry["default_consequence"] = "favor_owed"
	var flags: Dictionary = {}
	for key in run.narrative_flags:
		if str(key).begins_with("grand_casino"): flags[key] = run.narrative_flags[key]
	result["grand_flags"] = flags
	result["games"] = run.current_environment.get("game_states", {}).duplicate(true)
	return result.duplicate(true)
