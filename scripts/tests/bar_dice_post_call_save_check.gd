extends "res://scripts/tests/bar_dice_venue_terms_restore_check.gd"

# One new declared catalog case. It never loads either prior unsaved Call.
# Warm leaves a new unfunded Reveal; cold calls it ONCE, responds normally to
# a naturally triggered Health Inspector if present, then uses normal Menu Save.
# Settled is a separate process with zero game/event/financial inputs.
const POST_CALL_SEED := "BTH061-BAR-DICE-POSTCALL-QUAL-002"
const CoverTrace := preload("res://scripts/tests/bar_dice_cover_display_check.gd")


func _configure_fixture_host() -> void:
	app.set("GameSurfaceCanvasScript", CoverTrace.LabelCaptureCanvas)


func _fixture_seed() -> String:
	return POST_CALL_SEED


func _warm() -> void:
	await super._warm()
	if not failures.is_empty(): return
	if not _capture_cover("warm_saved_reveal"): return


func _capture_cover(label: String) -> bool:
	var canvas: Variant = app.game_surface_canvas
	if not _check(canvas is CoverTrace.LabelCaptureCanvas, label + " uses the normal preconstruction observing Canvas"): return false
	var before: Dictionary = _guard(app.run_state.to_dict()).account
	var ui: Dictionary = app._current_game_surface_ui_state()
	var module_state: Dictionary = app.current_game.surface_state(app.run_state, app.run_state.current_environment, ui)
	var host: Dictionary = app._game_view_snapshot()
	var captured: Dictionary = canvas.latest_cov.duplicate(true)
	if not facts.has("cover_boundaries"): facts["cover_boundaries"] = []
	facts.cover_boundaries.append({"label":label, "ui_phase":ui.get("bar_dice_ritual_phase", ""), "module":[module_state.get("covered_total", -1), module_state.get("at_risk_total", -1), module_state.get("returned_stake", -1)], "host":[host.get("covered_total", -1), host.get("at_risk_total", -1), host.get("returned_stake", -1)], "actual_draw":captured, "economy":_economy(), "menu_visible":app._run_menu_is_visible()})
	if not _check(_guard(app.run_state.to_dict()).account == before, label + " cover observation preserves wallet/root RNG"): return false
	return _check(str(captured.get("phase", "")) == "reveal" and int(captured.get("ante", -1)) == 6 and captured.get("flat", []) == [6,6,0] and str(captured.get("text_argument", "")).contains("COV $6") and str(captured.get("text_argument", "")).contains("RISK $6"), label + " actual draw text retains cover6/risk6/returned0")


func _cold() -> void:
	var parsed: Dictionary = NumericJson.parse(FileAccess.get_file_as_string(_expectation_path()))
	var record: Variant = parsed.get("data")
	if not _check(record is Dictionary and record.get("stage", "") == "reveal", "New case has its own saved unfunded Reveal"): return
	if not _inspect_saved("fresh_post_call_input", record.get("expected", {})): return
	if not _check(app.load_foundation_run() and app.run_state.seed_text == POST_CALL_SEED, "Normal Continue loads only the new declared seed"): return
	if not _check(app.enter_game("bar_dice"), "Normal new-case Bar Dice entry succeeds"): return
	await _frames(8)
	_connect_canvas()
	if not _compare_host(record.get("expected", {}), "New case cold Reveal"): return
	if not _capture_cover("cold_reveal_before_only_call"): return
	var before: Dictionary = _guard(app.run_state.to_dict())
	if not _check(before.cup.ante == 6 and before.cup.rounds == 0 and before.account.cash == 94, "No paid result existed in this new case"): return
	if not await _click("bar_dice_reveal"): return
	if not _check(_phase() == "call" and _guard(app.run_state.to_dict()).account == before.account, "Lift preserves unfunded wallet/root RNG"): return
	if not await _click("bar_dice_ack_call"): return
	var result: Dictionary = app.last_game_result.duplicate(true)
	var table: Dictionary = _table(app.run_state.to_dict())
	if not _check(bool(result.get(Authority.HOST_COMMITTED_KEY, false)), "Exactly one new Call commits"): return
	if not _check(int(result.get("bar_dice_stake", -1)) == 6 and int(result.get(Authority.HOST_WAGER_COST_KEY, -1)) == 6, "New Call funds exactly six once"): return
	if not _check(app.run_state.bankroll == 94 + int(result.get("bankroll_delta", 0)) and int(table.get("rounds_played", 0)) == 1 and _game_rows(app.run_state) == 1, "One natural result conserves wallet and records one round/action"): return
	if not _check(_digest(_ints(table.get("last_result", {}).get("player_dice", []))) == str(before.cup.dice), "One settlement uses this new saved cup's exact dice"): return
	if not _check(_phase() == "settle" and not _session().has("bar_dice_agreed_ante") and _ledger(app.run_state.to_dict()).get("pending_delivery", {}).is_empty(), "Settlement clears agreed cup and pending delivery"): return
	facts["new_paid_call_count"] = 1
	facts["post_call_ui"] = _ui_observation()
	if not await _ordinary_post_call_response(): return
	facts["after_response_ui"] = _ui_observation()
	if not await _idle_tumble(): return
	if not _save_permitted_screen(): return
	if not await _save_menu(): return
	var expected: Dictionary = _settled_projection(app.run_state.to_dict())
	if not _check(int(_table(app.run_state.to_dict()).get("rounds_played", 0)) == 1 and _game_rows(app.run_state) == 1, "Normal post-Call Save does not add a round or game action"): return
	if not _inspect_settled_save("post_call_manual_save", expected): return
	var file: FileAccess = FileAccess.open(_post_call_path(), FileAccess.WRITE)
	if not _check(file != null, "Private post-Call expectation opens"): return
	file.store_string(JSON.stringify({"task_id":"BTH061-BAR-DICE-REVEAL-RESTORE-001", "fixture_seed":POST_CALL_SEED, "stage":"post_call_manual_save", "expected":expected, "game_rows":1, "dice":before.cup.dice, "screen":app.current_screen}, "  "))
	file.close()
	facts["saved_outcome"] = {"cash": app.run_state.bankroll, "rounds": 1, "game_action_rows": _game_rows(app.run_state), "screen": app.current_screen, "new_paid_calls": 1, "original_or_prior_case_used": false}
	facts["completed"] = failures.is_empty()


func _ordinary_post_call_response() -> bool:
	if not app._event_choice_popup_is_visible():
		facts["event_response"] = {"state":"no_natural_popup", "choices_made":0, "forced_event_enqueue":false}
		return true
	var snapshot: Dictionary = app.pending_event_choice_popup_snapshot.duplicate(true)
	facts["event_response"] = {"event_id":snapshot.get("event_id", ""), "popup_type":snapshot.get("popup_type", ""), "choice":"finish_one", "choices_made":0, "forced_event_enqueue":false}
	if not _check(str(snapshot.get("event_id", "")) == "health_inspector" and str(snapshot.get("popup_type", "")) == "triggered_event", "Only a naturally displayed Health Inspector is predeclared for response; otherwise stop"): return false
	var button: Button = _choice_button(app.event_choice_popup_choices_list)
	if not _check(button != null and button.is_visible_in_tree() and not button.disabled and button.text == "One last move", "Rendered normal One last move button is available"): return false
	button.pressed.emit()
	await _frames(8)
	facts.event_response["choices_made"] = 1
	facts.event_response["after_popup"] = _ui_observation()
	return _check(not app._event_choice_popup_is_visible() and bool(app.run_state.narrative_flags.get("health_inspector_cleared", false)), "Ordinary Health Inspector response resolves its modal without a new wager")


func _choice_button(node: Node) -> Button:
	if node is Button and str(node.get_meta("event_id", "")) == "health_inspector" and str(node.get_meta("choice_id", "")) == "finish_one": return node as Button
	for child in node.get_children():
		var found: Button = _choice_button(child)
		if found != null: return found
	return null


func _save_permitted_screen() -> bool:
	return _check(app.current_screen in ["GAME", "ENVIRONMENT"] and not app._event_choice_popup_is_visible(), "Ordinary game/floor screen permits Menu Save after response")


func _ui_observation() -> Dictionary:
	return {"screen": app.current_screen, "popup_visible": app._event_choice_popup_is_visible(), "popup_event_id": app.pending_event_choice_popup_event_id, "closing_active": app.run_state.closing_time_active(), "transition_active": app.game_surface_canvas.surface_transition_animation_active(), "cash": app.run_state.bankroll}


func _game_rows(run: RunState) -> int:
	var count := 0
	for row in run.story_log:
		if row is Dictionary and row.get("type", "") == "game_action" and row.get("game_id", "") == "bar_dice": count += 1
	return count


func _post_call_path() -> String:
	return private_root.path_join("bar-dice-post-call-expectation.json")


func _settled() -> void:
	var parsed: Dictionary = NumericJson.parse(FileAccess.get_file_as_string(_post_call_path()))
	var record: Variant = parsed.get("data")
	if not _check(record is Dictionary and record.get("fixture_seed", "") == POST_CALL_SEED and record.get("stage", "") == "post_call_manual_save", "Read-only process requires the new case's completed manual Save"): return
	var expected: Dictionary = record.get("expected", {})
	if not _inspect_settled_save("read_only_post_call", expected): return
	if not _check(app.load_foundation_run() and app.run_state.seed_text == POST_CALL_SEED, "Fresh normal Continue loads the saved new outcome"): return
	await _frames(8)
	var now: Dictionary = _settled_projection(app.run_state.to_dict())
	facts["cold_outcome"] = {"cash":app.run_state.bankroll, "rounds":_table(app.run_state.to_dict()).get("rounds_played", 0), "game_rows":_game_rows(app.run_state), "projection_equal":_digest(now) == _digest(expected), "new_inputs":0}
	if not _check(_digest(now) == _digest(expected) and _game_rows(app.run_state) == 1, "Fresh Continue preserves exact wallet/root RNG/result/table/history and exactly one settled action"): return
	var table: Dictionary = _table(app.run_state.to_dict())
	if not _check(_digest(_ints(table.get("last_result", {}).get("player_dice", []))) == str(record.get("dice", "")), "Durable result retains the new cup's exact dice"): return
	facts["completed"] = true


func _settled_projection(data: Dictionary) -> Dictionary:
	# A completed ledger may be retired after an ordinary event advances its
	# checkpoint. The result, balances/RNG and all game/event history may not.
	var table: Dictionary = _table(data).duplicate(true)
	table.erase(Authority.LEDGER_KEY)
	return {"account":_guard(data).account, "clock_minutes":int(data.get("game_clock_minutes", -1)), "table":_digest(table), "story":_digest(data.get("story_log", []))}


func _inspect_settled_save(label: String, expected: Dictionary) -> bool:
	var boundary := {"label":label, "first_failed_stage":"", "scope":"Completed result only; initial unfunded Reveal uses the strict inherited ledger validator."}
	facts.boundaries.append(boundary)
	var parsed: Dictionary = NumericJson.parse(Codec.preserve_blackjack_ledger_integer_tokens(FileAccess.get_file_as_string(app.save_service.run_save_path(SLOT))))
	if not _gate(int(parsed.get("error", FAILED)) == OK and parsed.get("data") is Dictionary, boundary, "official_envelope_parse"): return false
	var storage: Dictionary = parsed.data.get("run_state", {})
	if not _gate(Codec.storage_envelope_valid(storage) and Codec.storage_contents_valid(storage), boundary, "official_storage_validation"): return false
	var encoded: Dictionary = Codec.unpack_from_storage(storage)
	if not _gate(not encoded.is_empty(), boundary, "official_unpack"): return false
	var raw: Dictionary = Codec.decode(encoded)
	if not _gate(_digest(_settled_projection(raw)) == _digest(expected), boundary, "saved_outcome_projection_matches_live"): return false
	var raw_ledger: Dictionary = _ledger(raw)
	var raw_session: Dictionary = raw_ledger.get("session", {})
	if not _gate(not bool(raw_session.get("rolled", false)) and str(raw_session.get("bar_dice_ritual_phase", "")) in ["", "settle"] and raw_ledger.get("pending_delivery", {}).is_empty() and not raw_session.has("bar_dice_agreed_ante"), boundary, "no_open_cup_or_pending_delivery_can_be_excused"): return false
	if not raw_ledger.is_empty():
		var raw_binding: String = RunState.action_authority_table_binding("bar_dice", raw.get("current_environment", {}))
		if not _gate(not Authority.validate_persisted_ledger(raw_ledger, raw_binding).is_empty(), boundary, "raw_completed_ledger_still_has_valid_shape_and_binding"): return false
	var loaded: Variant = SaveService.new().load_run(SLOT)
	if not _gate(loaded is RunState, boundary, "official_load_run"): return false
	if not _gate(_digest(_settled_projection(loaded.to_dict())) == _digest(_settled_projection(raw)), boundary, "official_load_preserves_money_root_rng_result_and_history"): return false
	var loaded_ledger: Dictionary = _ledger(loaded.to_dict())
	boundary["raw_ledger_present"] = not raw_ledger.is_empty()
	boundary["loaded_ledger_present"] = not loaded_ledger.is_empty()
	boundary["completed_ledger_disposition"] = "retired" if loaded_ledger.is_empty() else "retained_valid"
	if loaded_ledger.is_empty(): return true
	var loaded_session: Dictionary = loaded_ledger.get("session", {})
	if not _gate(not bool(loaded_session.get("rolled", false)) and str(loaded_session.get("bar_dice_ritual_phase", "")) in ["", "settle"] and loaded_ledger.get("pending_delivery", {}).is_empty() and not loaded_session.has("bar_dice_agreed_ante"), boundary, "official_load_does_not_create_a_new_open_cup_or_delivery"): return false
	var binding: String = RunState.action_authority_table_binding("bar_dice", loaded.current_environment)
	return _gate(not Authority.validate_persisted_ledger(loaded_ledger, binding, loaded.action_authority_checkpoint_fingerprint()).is_empty(), boundary, "any_retained_ledger_still_validates_current_checkpoint")


func _finish() -> void:
	facts["fixture_seed"] = POST_CALL_SEED
	facts["scope"] = "One new catalog BarWake/Payday fixture with explicit engineering clock23:00/Day205:30, normal renderer actions and Menu Save/Continue. Never a prior unsaved Call or original profile. At most one new Call and one naturally displayed Health Inspector finish_one button; other prompts stop. Settled stage has zero game/event/financial inputs."
	facts["stage"] = stage
	facts["actions"] = actions
	facts["blocked"] = blocks
	facts["source_sha256"] = {"game":FileAccess.get_sha256("res://scripts/games/bar_dice.gd"), "test":FileAccess.get_sha256(get_script().resource_path), "venue":FileAccess.get_sha256("res://scripts/tests/bar_dice_venue_terms_restore_check.gd")}
	var result: Dictionary = {"checks":checks, "failures":failures, "facts":facts}
	var output: String = OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty() and not private_root.is_empty() and _inside(output):
		var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(result, "  ")); file.close()
	print("BAR_DICE_POST_CALL_SAVE_RESULT " + JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
