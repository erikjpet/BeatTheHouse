extends "res://scripts/tests/scenario_venue_cycle_captured_check.gd"

# Prospective producer controls are synthetic. Captured service outcomes are
# never redeemed again: prospective captured modes add only proposed metadata to
# a private clone of an already-committed row, then exercise Save/Continue/UI.
const Fingerprint := preload("res://scripts/core/game_ritual_runtime.gd")
const Comp := preload("res://scripts/core/grand_casino_run_facade.gd")
const Archive := preload("res://scripts/core/run_money_flow_archive.gd")
const READER := "_saved_players_card_comp_feedback_from_story_log"
const WITNESS_KEYS := ["feedback_schema", "feedback_id", "comp_uses_before", "comp_uses_after"]

class EligibilityControl:
	extends RunState
	var comp_eligible := true
	func demo_objective_status(_environment: Dictionary = {}) -> Dictionary:
		return {"players_card_eligible": comp_eligible}

func _run() -> void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-"), "explicit private diagnostic root required"):
		_finish(); return
	var mode := OS.get_environment("BTH_COMP_FEEDBACK_CASE")
	if mode == "producer":
		_producer_controls(); _finish(); return
	if not _check(mode in ["legacy_drink", "legacy_suite", "prospective_drink", "prospective_suite", "restore_drink", "restore_suite"], "explicit captured or prospective case required"):
		_finish(); return
	var kind := "drink" if mode.ends_with("drink") else "suite"
	var slot := "comp_feedback_" + kind if mode.begins_with("restore") else "foundation_ui_autosave"
	if not mode.begins_with("restore"): _install(OS.get_environment("BTH_CAPTURED_FIXTURE"))
	if not failures.is_empty(): _finish(); return
	root.size = Vector2i(1280, 720)
	var app := Host.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	app.set_anchors_preset(Control.PRESET_TOP_LEFT); app.size = Vector2(root.size)
	for frame in range(3): await process_frame
	app.autosave_slot_id = slot
	if not _check(app.load_foundation_run(), "ordinary Continue loads unchanged copied service authority"):
		app.queue_free(); await process_frame; _finish(); return
	for frame in range(3): await process_frame
	app.set_process(false)
	var protected := _protected_comp(app.run_state)
	_check(app.run_state.bankroll == 71 and app.run_state.grand_casino_chips == 165, "actual captured wallet71cash/165chips remains unchanged")
	var tail: Dictionary = app.run_state.story_log.back()
	_check(str(tail.get("id", "")) == ("players_card_drink_comp" if kind == "drink" else "players_card_suite_rest_comp"), "captured final row is the actual accepted service")
	if mode.begins_with("restore"):
		var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://comp-feedback-" + kind + "-expected.json"))
		if _check(typeof(expected) == TYPE_DICTIONARY, "prior process prospective expectation exists"):
			_check(_same_json_values(protected, expected.protected), "independent process preserves every protected service/economy/history/RNG field")
			_check(_same_json_values(tail, expected.tail), "independent process retains exact proposed stamp once")
		await _assert_saved_view(app, str(tail.message))
	else:
		_check(not tail.has("feedback_schema"), "historical accepted row remains unstamped")
		_check((app.call(READER, app.run_state.story_log) as Dictionary).is_empty(), "legacy row does not acquire invented recency")
		var legacy := _read_view(app)
		_check(str(legacy.get("text", "")).contains("Blackjack +20") and not str(legacy.get("text", "")).contains(str(tail.message)), "unstamped legacy cold fallback remains unchanged")
		var original_story := Fingerprint.canonical_fingerprint(app.run_state.story_log)
		if not await _save_continue_control(app, "comp_legacy_" + kind, protected, "", false):
			app.queue_free(); await process_frame; _finish(); return
		_check(Fingerprint.canonical_fingerprint(app.run_state.story_log) == original_story, "normal Save/Continue does not retroactively stamp or rewrite any legacy history")
		if mode.begins_with("prospective"):
			# SYNTHETIC READER CONTROL ONLY, not production migration or a replay.
			var row: Dictionary = app.run_state.story_log.back().duplicate(true)
			var flag := "grand_casino_comp_drink_tokens" if kind == "drink" else "grand_casino_comp_suite_rests"
			row["feedback_schema"] = Comp.PLAYERS_CARD_COMP_FEEDBACK_SCHEMA
			row["comp_uses_after"] = int(app.run_state.narrative_flags.get(flag, 0))
			row["comp_uses_before"] = int(row.comp_uses_after) + 1
			row["feedback_id"] = Comp.players_card_comp_feedback_identity(row)
			app.run_state.story_log[app.run_state.story_log.size() - 1] = row
			_check(_protected_comp(app.run_state) == protected, "synthetic metadata clone does not redeem/recover/advance/pay again")
			_reader_controls(app, row)
			app.last_game_result = app.call(READER, app.run_state.story_log)
			await _assert_saved_view(app, str(row.message))
			for cycle in range(2):
				if not await _save_continue_control(app, "comp_feedback_" + kind, protected, str(row.message), true): break
				facts["tail_difference_cycle_" + str(cycle + 1)] = _different_paths(row, app.run_state.story_log.back())
				facts["tail_types_cycle_" + str(cycle + 1)] = {"expected_before": typeof(row.comp_uses_before), "expected_after": typeof(row.comp_uses_after), "actual_before": typeof(app.run_state.story_log.back().get("comp_uses_before")), "actual_after": typeof(app.run_state.story_log.back().get("comp_uses_after"))}
				_check(_same_json_values(app.run_state.story_log.back(), row), "Save/Continue preserves all receipt fields across exact-valued JSON numeric transport, cycle " + str(cycle + 1))
			FileAccess.open("user://comp-feedback-" + kind + "-expected.json", FileAccess.WRITE).store_string(JSON.stringify({"protected": protected, "tail": row}))
			facts["prospective_mode_limit"] = "Stamp applied only to a detached private reader clone of an already committed public row; original is unchanged. Actual new producer tested separately on synthetic new state. Future normal-Web accepted service required for end-to-end qualification."
	_check(_protected_comp(app.run_state) == protected, "all readers preserve money/Heat/Drunk/counters/clock/history/paid state/RNG")
	facts["kind"] = kind
	facts["protected"] = protected
	app.save_service.wait_for_async_save()
	app.queue_free(); await process_frame
	_finish()

func _control() -> EligibilityControl:
	var run := EligibilityControl.new()
	run.start_new("COMP-FEEDBACK-SYNTHETIC-CONTROL")
	run.bankroll = 71; run.grand_casino_chips = 165
	run.current_environment = {"id": "synthetic_comp_cage", "archetype_id": "grand_casino_cage", "kind": "boss", "tier": 5}
	run.narrative_flags["grand_casino_comp_drink_tokens"] = 2
	run.narrative_flags["grand_casino_comp_suite_rests"] = 1
	return run

func _producer_controls() -> void:
	var host := Host.new()
	host.library = ContentLibrary.new(); host.library.load(false)
	host.user_settings = UserSettings.new()
	if not _check(host._ensure_run_ui_stage_scripts(0), "normal detached UI dependency loader initialized"):
		host.free(); return
	for comp_id in ["drink", "suite_rest"]:
		var run := _control(); var old_control := _control()
		if comp_id == "suite_rest":
			for target in [run, old_control]:
				target.suspicion["level"] = 12
				target.drunk_level = 8
		host.run_state = run
		var before := _protected_comp(run)
		var result: Dictionary = run.grand_casino_players_card_comp_result(comp_id)
		if not _check(bool(result.get("ok", false)), "actual Core comp DTO accepts synthetic eligible " + comp_id): continue
		_check(_protected_comp(run) == before, "preview adds no stamp, token debit, recovery or clock change")
		var row: Dictionary = result.deltas.story_log[0]
		_check(str(row.get("feedback_schema", "")) == Comp.PLAYERS_CARD_COMP_FEEDBACK_SCHEMA, "new accepted DTO carries versioned presentation witness")
		_check(str(row.get("feedback_id", "")) == Comp.players_card_comp_feedback_identity(row), "witness binds exact service/location/uses/public text")
		_check(result.deltas.story_log.size() == 1 and int(row.comp_uses_after) == int(row.comp_uses_before) - 1, "same one consequence row and one existing comp use")
		_check(Archive.money_legs(row) == {"cash": 0}, "presentation stamp creates no phantom money movement")
		var old_result := result.duplicate(true)
		for key in WITNESS_KEYS: old_result.deltas.story_log[0].erase(key)
		GameModule.apply_result(run, result)
		GameModule.apply_result(old_control, old_result)
		_check(_protected_comp(run, false) == _protected_comp(old_control, false), "new-vs-unstamped control has identical Core service effects and gameplay")
		_check(run.bankroll == 71 and run.grand_casino_chips == 165, "Core comp does not touch cash or chips")
		_check(run.story_log.size() == before.story_count + 1, "actual Core commits the existing service row once")
		_reader_controls(host, run.story_log.back())
		facts["synthetic_" + comp_id] = {"row": row, "duration_requested": result.get("duration_minutes", 0), "limit": "Core DTO/application control; UI240-minute/turn acceptance path is unchanged and needs later owner Web qualification."}
	for rejected_case in ["empty_drink", "empty_suite", "ineligible", "outside", "unknown"]:
		var run := _control(); host.run_state = run
		if rejected_case == "empty_drink": run.narrative_flags.grand_casino_comp_drink_tokens = 0
		if rejected_case == "empty_suite": run.narrative_flags.grand_casino_comp_suite_rests = 0
		if rejected_case == "ineligible": run.comp_eligible = false
		if rejected_case == "outside": run.current_environment.archetype_id = "bar"
		var before := _protected_comp(run)
		var id := "suite_rest" if rejected_case == "empty_suite" else ("unknown" if rejected_case == "unknown" else "drink")
		var result: Dictionary = run.grand_casino_players_card_comp_result(id)
		_check(not bool(result.get("ok", false)) and result.get("deltas", {}).get("story_log", []).is_empty(), "rejected/depleted preview emits no success witness: " + rejected_case)
		_check(_protected_comp(run) == before, "rejected preview changes no service/finance/history/RNG: " + rejected_case)
	host.free()

func _reader_controls(host: Host, row: Dictionary) -> void:
	var before := _protected_comp(host.run_state)
	var result: Dictionary = host.call(READER, [row])
	_check(str(result.get("message", "")) == str(row.message) and str(result.get("summary_source", "")) == "saved_players_card_comp_feedback", "supported latest comp restores exact public acknowledgement")
	for key in ["bankroll_delta", "chips_delta", "suspicion_delta", "duration_minutes", "alcohol_intake", "drunk_delta"]:
		_check(int(result.get(key, 0)) == 0, "restored presentation has neutral " + key)
	_check(host.call(READER, [row]) == result, "repeated reader is stable and never consumes a comp")
	var json_row: Variant = JSON.parse_string(JSON.stringify(row))
	_check(not (host.call(READER, [json_row]) as Dictionary).is_empty(), "normal JSON numeric transport retains receipt identity")
	for later in [{"type": "travel", "message": "Later trip."}, {"type": "game_action", "game_id": "blackjack", "bankroll_delta": 5}, {"type": "event", "message": "Later event."}, {"type": "debt_interest", "message": "Later interest."}, {"type": "service_hook", "message": "Later unrelated service."}, {"type": "scenario_action_feedback"}, {"type": "world_sequence_feedback"}, null, {}]:
		_check((host.call(READER, [row, later]) as Dictionary).is_empty(), "no backwards comp scan past any later record")
	_ordering_controls(host, row)
	for key in ["type", "id", "feedback_schema", "feedback_id", "environment_id", "environment_archetype_id", "message", "comp_uses_before", "comp_uses_after"]:
		var missing := row.duplicate(true); missing.erase(key)
		_check((host.call(READER, [missing]) as Dictionary).is_empty(), "required recorded receipt field: " + key)
	for change in [{"feedback_schema": "future"}, {"id": "other_service"}, {"environment_archetype_id": "bar"}, {"environment_id": "mismatched"}, {"message": "Mismatched public answer."}, {"comp_uses_before": "2"}, {"comp_uses_before": 0}, {"comp_uses_after": -1}, {"comp_uses_after": 1.5}, {"comp_uses_after": INF}, {"bankroll_delta": 20}, {"chips_delta": 20}, {"cash_delta": "0"}, {"currency_delta": NAN}]:
		_check((host.call(READER, [row.merged(change, true)]) as Dictionary).is_empty(), "unsupported/malformed/mismatched or monetary receipt fails closed")
	var legacy := row.duplicate(true)
	for key in WITNESS_KEYS: legacy.erase(key)
	_check((host.call(READER, [legacy]) as Dictionary).is_empty(), "old unstamped service is not retroactively migrated")
	var flag := "grand_casino_comp_drink_tokens" if str(row.id) == "players_card_drink_comp" else "grand_casino_comp_suite_rests"
	var saved_uses: Variant = host.run_state.narrative_flags.get(flag)
	host.run_state.narrative_flags[flag] = int(row.comp_uses_after) + 1
	_check((host.call(READER, [row]) as Dictionary).is_empty(), "receipt must match the saved consumed counter, not just its own identity")
	host.run_state.narrative_flags[flag] = saved_uses
	var foreign := row.merged({"currency": "untrusted", "private_handler_state": {"unrelated": true}}, true)
	var allowed: Dictionary = host.call(READER, [foreign])
	_check(not allowed.has("private_handler_state") and str(allowed.get("currency", "")) != "untrusted", "reader admits public acknowledgement only, not foreign handlers/currency")
	_check(_protected_comp(host.run_state) == before, "all reader guards preserve accepted services and full protected gameplay")

func _ordering_controls(host: Host, row: Dictionary) -> void:
	var later_game := {"type": "game_action", "game_id": "blackjack", "environment_archetype_id": "grand_casino", "currency": "chips", "currency_delta": 0, "bankroll_delta": 0, "message": "Synthetic newer game feedback."}
	var game: Dictionary = host._game_result_from_story_log([row, later_game])
	_check(str(game.get("message", "")) == str(later_game.message), "existing game reader selects newer game, not earlier comp")
	var scenario := {"type": "scenario_action_feedback", "feedback_schema": "bth.scenario_action_feedback/v1", "scenario_id": "synthetic_scenario", "node_id": "synthetic_node", "environment_visit_id": "synthetic_visit", "command_id": "synthetic_command", "command_receipt_id": "synthetic_receipt", "message": "Synthetic newer room acknowledgement.", "bankroll_delta": 0, "chips_delta": 0, "suspicion_delta": 0}
	scenario["feedback_id"] = JSON.stringify([scenario.scenario_id, scenario.node_id, scenario.environment_visit_id, scenario.command_id, scenario.command_receipt_id])
	var scenario_result: Dictionary = host._saved_scenario_action_feedback_from_story_log([row, scenario])
	_check(str(scenario_result.get("message", "")) == str(scenario.message) and (host.call(READER, [row, scenario]) as Dictionary).is_empty(), "newer valid scenario acknowledgement owns its existing final-row reader")
	var delivery := {"type": "world_sequence_feedback", "feedback_schema": "bth.world_sequence_feedback/v1", "channel_id": "delivery_handoff", "feedback_id": "synthetic_delivery_feedback", "owner_token": "synthetic_owner", "outcome_receipt_id": "synthetic_outcome", "message": "Synthetic newer delivery acknowledgement.", "bankroll_delta": 0, "chips_delta": 0, "suspicion_delta": 0}
	var delivery_result: Dictionary = host._saved_world_sequence_feedback_from_story_log([row, delivery])
	_check(str(delivery_result.get("message", "")) == str(delivery.message) and (host.call(READER, [row, delivery]) as Dictionary).is_empty(), "newer valid delivery acknowledgement owns its existing final-row reader")
	# A synthetic presentation-only later comp uses the same saved counter. No
	# actual second service is created/applied to establish this reader boundary.
	var newer_comp := row.duplicate(true)
	newer_comp["message"] = "Synthetic newer supported comp acknowledgement."
	newer_comp["feedback_id"] = Comp.players_card_comp_feedback_identity(newer_comp)
	var comp_result: Dictionary = host.call(READER, [row, newer_comp])
	_check(str(comp_result.get("message", "")) == str(newer_comp.message), "latest supported comp wins by log position, not an older receipt search")
	for later in [{"type": "event", "message": "Synthetic newer event feedback."}, {"type": "debt_interest", "message": "Synthetic newer interest feedback."}]:
		var generic: Dictionary = host._result_from_story_log([row, later])
		_check(str(generic.get("message", "")) == str(later.message) and (host.call(READER, [row, later]) as Dictionary).is_empty(), "event/interest tail blocks comp restoration and remains available to existing generic reader")
	var unknown := row.duplicate(true); unknown.feedback_schema = "unsupported_future_comp"
	_check((host.call(READER, [row, unknown]) as Dictionary).is_empty(), "unknown final comp witness cannot trigger a backwards supported-comp search")
	facts["ordering_scope"] = "Supported final comp/game/scenario/delivery acknowledgement ordering and final-only comp exclusion behind generic event/interest/travel rows. Unchanged generic-vs-game fallback policy is not expanded into a separate global cold-feedback redesign."

func _save_continue_control(app: Host, slot: String, protected: Dictionary, message: String, expect_comp: bool) -> bool:
	app.autosave_slot_id = slot
	app.save_foundation_run(); app.save_service.wait_for_async_save()
	if not _check(app.return_to_main_menu(), "normal Main Menu after private Save"): return false
	app.save_service = SaveService.new()
	for key in ["last_hook_result", "last_item_result", "last_game_result", "last_environment_runtime_result"]:
		app.set(key, {"message": "Synthetic stale " + key, "bankroll_delta": 999, "chips_delta": 999})
	app.immediate_environment_acknowledgement = "Synthetic stale immediate acknowledgement."
	if not _check(app.load_foundation_run(), "same-host fresh-service Continue clears stale UI before selecting durable feedback"): return false
	app.set_process(false)
	_check(app.last_hook_result.is_empty() and app.last_item_result.is_empty() and app.last_environment_runtime_result.is_empty() and app.immediate_environment_acknowledgement.is_empty(), "all competing stale transient channels are cleared on actual Continue")
	if expect_comp:
		await _assert_saved_view(app, message)
	else:
		var legacy := _read_view(app)
		_check(str(legacy.get("text", "")).contains("Blackjack +20") and not str(legacy.get("text", "")).contains("Synthetic stale"), "unstamped history retains prior fallback rather than transient UI or invented comp recency")
	_check(_protected_comp(app.run_state) == protected, "Save/Continue replays no charge, service, reward, recovery, token consumption or clock advance")
	return true

func _read_view(app: Host) -> Dictionary:
	var before := Fingerprint.canonical_fingerprint(app.run_state.to_save_snapshot())
	var view: Dictionary = app._environment_result_feedback_view()
	app._refresh_environment_result_feedback()
	_check(app.environment_result_body_label.text == str(view.get("text", "")), "actual HUD Result Label is bound to chosen feedback")
	_check(Fingerprint.canonical_fingerprint(app.run_state.to_save_snapshot()) == before, "HUD reader and label binding are full-state read-only")
	facts["last_view_text"] = str(view.get("text", ""))
	return view

func _assert_saved_view(app: Host, message: String) -> void:
	var view := _read_view(app)
	for frame in range(3): await process_frame
	var text := str(view.get("text", ""))
	_check(text.contains(message) and not text.contains("Blackjack +20") and not text.contains("Chip change: +20"), "cold comp acknowledgement replaces historical game feedback")
	_check(str(view.get("result", {}).get("summary_source", "")) == "saved_players_card_comp_feedback", "cold selection uses supported final comp witness")
	facts["label_layout"] = {"size": str(app.environment_result_body_label.size), "lines": app.environment_result_body_label.get_line_count(), "visible_lines": app.environment_result_body_label.get_visible_line_count(), "line_height": app.environment_result_body_label.get_line_height(), "text": app.environment_result_body_label.text, "parent_visible": app.environment_result_body_label.is_visible_in_tree(), "host_size": str(app.size)}
	_check(app.environment_result_body_label.get_line_count() <= app.environment_result_body_label.get_visible_line_count(), "acknowledgement fits actual HUD visible lines")

func _protected_comp(run: RunState, include_crew_authority: bool = true) -> Dictionary:
	var source := run.to_save_snapshot()
	var rows: Array = run.story_log.duplicate(true)
	for row in rows:
		if typeof(row) == TYPE_DICTIONARY and str(row.get("type", "")) == "service_hook" and str(row.get("id", "")) in ["players_card_drink_comp", "players_card_suite_rest_comp"]:
			for key in WITNESS_KEYS: row.erase(key)
	var result := {"story_count": rows.size(), "original_story": Fingerprint.canonical_fingerprint(rows)}
	for key in ["bankroll", "grand_casino_chips", "suspicion", "drunk_level", "alcoholic_level", "pending_drunk_absorption", "drunk_distortion_suppression_turns", "debt", "grand_casino_atm_debt", "inventory", "rng_seed", "rng_state", "numbers_state", "active_delivery_run", "run_status", "run_spending_score", "story_money_archive", "narrative_flags", "event_cadence", "game_clock_minutes", "pending_bags", "home_state"]:
		result[key] = Fingerprint.canonical_fingerprint(source.get(key))
	if include_crew_authority:
		result["crew_state"] = Fingerprint.canonical_fingerprint(source.get("crew_state"))
	result["paid_game_states"] = Fingerprint.canonical_fingerprint(run.current_environment.get("game_states", {}))
	return result

func _same_json_values(left: Variant, right: Variant) -> bool:
	if typeof(left) in [TYPE_INT, TYPE_FLOAT] and typeof(right) in [TYPE_INT, TYPE_FLOAT]:
		return left == right
	if typeof(left) != typeof(right): return false
	if typeof(left) == TYPE_DICTIONARY:
		if left.size() != right.size(): return false
		for key in left:
			if not right.has(key) or not _same_json_values(left[key], right[key]): return false
		return true
	if typeof(left) == TYPE_ARRAY:
		if left.size() != right.size(): return false
		for index in range(left.size()):
			if not _same_json_values(left[index], right[index]): return false
		return true
	return left == right

func _finish() -> void:
	facts["scope"] = "Prospective comp acknowledgement producer/reader and legacy-safe ordered HUD selection. Synthetic Core controls and detached reader stamps are labelled; no accepted historical service is replayed. Actual normal service clock/turn and owner-Web path remain pending coordinated qualification."
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty(): FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "facts": facts}, "  "))
	print("PLAYERS_CARD_COMP_COLD_FEEDBACK checks=", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
