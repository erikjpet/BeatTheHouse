extends SceneTree

# Synthetic practice room and clock epoch, never the completed R04 player cup.
# Production Host, Bar Dice renderer and its drawn hit regions handle every
# gameplay click. Only the final duplicate/forged delivery probes call authority
# directly. The cold stage reads the already-settled cup; it places no new bet.
const MainScene := preload("res://scenes/main.tscn")
const BarDice := preload("res://scripts/games/bar_dice.gd")
const Authority := preload("res://scripts/core/blackjack_action_authority.gd")
const Runtime := preload("res://scripts/core/game_ritual_runtime.gd")
const SLOT := "bar_dice_warm_host"
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}
var app: Variant
var actions: Array = []
var blocks: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _private_roots(): _finish(); return
	root.size = Vector2i(1280, 720)
	app = MainScene.instantiate()
	app.set("show_game_library_launcher", true)
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", SLOT)
	root.add_child(app)
	await _frames(8)
	if OS.get_environment("BTH_BAR_DICE_HOST_STAGE") == "cold":
		await _cold()
	else:
		await _warm()
	_check(bool(facts.get("completed", false)), "requested warm or cold stage reaches its final assertion")
	app.save_service.wait_for_async_save()
	app.queue_free()
	await _frames(2)
	_finish()


func _warm() -> void:
	# These are the existing practice launcher's supported configuration inputs.
	app.open_game_test_menu()
	await _frames(2)
	if not _check(app.game_test_seed_input != null and app.game_test_bankroll_input != null and app.game_test_generation_overrides_text != null, "ordinary Games menu builds supported practice configuration controls"): return
	app.game_test_seed_input.text = "SYNTHETIC-BAR-DICE-WARM-CLOCK"
	app.game_test_bankroll_input.value = 167
	app.game_test_stake_floor_input.value = 22
	app.game_test_stake_ceiling_input.value = 22
	app.game_test_generation_overrides_text.text = JSON.stringify({"environment": {"archetype_id": "bar", "kind": "casino", "economic_profile": {"stake_floor": 22, "stake_ceiling": 22, "game_stake_floor_overrides": {}, "game_stake_ceiling_overrides": {}}}})
	var started: Dictionary = app.start_game_test_session("bar_dice")
	if not _check(bool(started.get("ok", false)), "production practice launcher opens synthetic Bar Dice room"): return
	await _frames(8)
	_check(app.run_state.bankroll == 167 and _table().get("stake_ladder", []) == [22], "supported launcher config supplies167 cash and22 cash ante")
	# Explicit clock-domain control: save a synthetic checkpoint ahead of process
	# time, then let the unchanged official Continue epoch loader restore it.
	var synthetic_checkpoint := Time.get_ticks_msec() + 120000
	app.run_state.surface_clock_checkpoint_msec = synthetic_checkpoint
	_check(app.save_service.save_run(app.run_state, SLOT) == OK, "official private SaveService stores synthetic future epoch")
	if not _check(app.load_foundation_run(), "ordinary Host Continue loads synthetic clock fixture"): return
	if not _check(app.enter_game("bar_dice"), "ordinary table reentry restores future epoch before any wager"): return
	await _frames(8)
	var canvas: Variant = app.game_surface_canvas
	var opened_clock: int = canvas.surface_simulation_time_msec()
	_check(opened_clock >= synthetic_checkpoint and opened_clock > Time.get_ticks_msec() + 100000, "real Host and canvas use saved surface epoch ahead of process clock")
	canvas.surface_action.connect(func(action: String, index: int, confirmed: bool) -> void: actions.append({"action": action, "index": index, "confirm": confirmed}))
	canvas.surface_action_blocked.connect(func(action: String, reason: String) -> void: blocks.append({"action": action, "reason": reason}))
	facts["fixture"] = {"kind": "synthetic production practice launcher", "cash": 167, "ante": 22, "future_checkpoint": synthetic_checkpoint, "opened_surface_clock": opened_clock, "process_clock": Time.get_ticks_msec()}
	if not await _click("bar_dice_roll"): return
	_check(_phase() == "cover" and app.run_state.bankroll == 167 and int(_table().get("rounds_played", 0)) == 0, "Roll Cup starts one unfunded covered cup")
	if not await _click("bar_dice_ack_cover"): return
	_check(_phase() == "shake" and bool(_session().get("rolled", false)), "Take Cover opens the same cup")
	var initial_dice: Array = _session().get("dice", []).duplicate(true)
	_check(initial_dice.size() == 5 and int(_session().get("shake_number", 0)) == 1, "opening has five authoritative dice and first shake")
	if not await _idle_tumble("opening"): return
	for shake in [2, 3]:
		if not await _click("bar_dice_shake"): return
		_check(int(_session().get("shake_number", 0)) == shake and _phase() == "shake", "drawn Shake accepts exactly shake%d in same warm cup" % shake)
		if not await _idle_tumble("shake%d" % shake): return
	var ready_session := _session().duplicate(true)
	var ready_accounting := _accounting()
	await _save_menu()
	var open_copy: Variant = SaveService.new().load_run(SLOT)
	_check(open_copy is RunState and _wire(_ledger(open_copy)) == _wire(_ledger(app.run_state)), "normal Menu Save retains exact open cup authority through official codec")
	_check(open_copy is RunState and open_copy.bankroll == 167 and _wire(_ledger(open_copy).get("session", {}).get("dice", [])) == _wire(ready_session.get("dice", [])), "saved open cup preserves167 cash and all chosen dice")
	app.run_menu_resume_button.pressed.emit()
	await _frames(3)
	_check(_accounting() == ready_accounting, "Menu Save and Resume preserve all wallets rootRNG and round accounting")
	if not await _click("bar_dice_resolve"): return
	_check(_phase() == "throw" and _session().get("dice", []) == ready_session.get("dice", []), "warm drawn Settle progresses to Throw with exact same dice")
	if not await _click("bar_dice_throw"): return
	_check(_phase() == "reveal", "drawn Slam Cup progresses to Reveal")
	if not await _click("bar_dice_reveal"): return
	_check(_phase() == "call", "drawn Lift Cup progresses to Call")
	_check(app.run_state.bankroll == 167 and int(_table().get("rounds_played", 0)) == 0, "all warm ritual steps preserve unfunded cash until single Call")
	if not await _click("bar_dice_ack_call"): return
	var result: Dictionary = app.last_game_result
	_check(bool(result.get(Authority.HOST_COMMITTED_KEY, false)), "drawn Call It commits one authenticated result")
	_check(int(result.get("bar_dice_stake", -1)) == 22 and int(result.get(Authority.HOST_WAGER_COST_KEY, -1)) == 22, "committed result and funding retain exact22 ante")
	_check(int(_table().get("rounds_played", 0)) == 1 and app.run_state.bankroll == 167 + int(result.get("bankroll_delta", 0)), "one natural synthetic result conserves exact wallet delta")
	_check(_table().get("last_result", {}).get("player_dice", []) == ready_session.get("dice", []), "settlement uses the final displayed cup without reroll")
	_check(_phase() == "settle" and _ledger(app.run_state).get("pending_delivery", {}).is_empty(), "settled cup has no pending delivery")
	var delivery: Dictionary = result.get(Authority.HOST_DELIVERY_KEY, {})
	_check(not delivery.is_empty(), "single committed result retains authenticated replay claim")
	var settled := _wire(app.run_state.to_dict())
	var replay: Dictionary = app._sealed_action_host_resolve_intent("roll", 22, delivery)
	_check(bool(replay.get("ok", false)) and _wire(app.run_state.to_dict()) == settled, "exact delivery replay changes no complete run field")
	var forged := delivery.duplicate(true)
	forged["stake"] = 23
	var rejected: Dictionary = app._sealed_action_host_resolve_intent("roll", 23, forged)
	_check(not bool(rejected.get("ok", true)) and _wire(app.run_state.to_dict()) == settled, "forged replay stake rejects without money RNG history or authority mutation")
	await _save_menu()
	var expected := _outcome_guard(app.run_state)
	var saved: Variant = SaveService.new().load_run(SLOT)
	_check(saved is RunState and _outcome_guard(saved) == expected, "official outcome save retains one full settled ledger and protected accounting")
	var record := {"expected": expected, "final_dice": ready_session.get("dice", []), "cash_delta": result.get("bankroll_delta", 0), "outcome": result.get("outcome", ""), "actions": actions}
	var file := FileAccess.open(_expectation_path(), FileAccess.WRITE)
	_check(file != null, "private expectation receipt opens")
	if file != null: file.store_string(JSON.stringify(record, "  ")); file.close()
	facts["outcome"] = record
	facts["blocked_actions"] = blocks
	_check(blocks.is_empty(), "all intended warm gameplay clicks passed production animation gate")
	facts["completed"] = true


func _cold() -> void:
	var record: Variant = JSON.parse_string(FileAccess.get_file_as_string(_expectation_path()))
	if not _check(record is Dictionary, "cold process reads prior warm public expectation"): return
	var before: Variant = SaveService.new().load_run(SLOT)
	if not _check(before is RunState, "fresh official SaveService reads settled warm run"): return
	_check(_outcome_guard(before) == record.get("expected", {}), "new process preserves complete settled ledger and protected accounting")
	if not _check(app.load_foundation_run(), "normal cold Host Continue restores settled synthetic cup"): return
	if not _check(app.enter_game("bar_dice"), "normal cold table entry succeeds without new paid input"): return
	await _frames(8)
	_check(_outcome_guard(app.run_state) == record.get("expected", {}), "cold Continue and entry do not repeat funding result history RNG or authority")
	_check(int(_table().get("rounds_played", 0)) == 1 and _table().get("last_result", {}).get("player_dice", []) == record.get("final_dice", []), "cold view retains exactly one settled result and final cup")
	_check(not bool(_session().get("rolled", false)) and _ledger(app.run_state).get("pending_delivery", {}).is_empty(), "cold settlement cannot reopen a rolled pending cup")
	var early_feedback := {"surface_clock": app.game_surface_canvas.surface_simulation_time_msec(), "started_msec": _table().get("last_result", {}).get("resolved_at_msec", 0), "elapsed_sec": app.game_surface_canvas.surface_elapsed(BarDice.TUMBLE_CHANNEL), "blocked": app.game_surface_canvas.surface_action_is_blocked("bar_dice_roll")}
	# Save can legitimately capture the terminal feedback before its900ms end.
	# Give that existing feedback its bounded passive interval, without clearing
	# animation ids, clicking, or rewriting any persisted authority.
	await _idle_tumble("cold_settlement")
	_check(not app.game_surface_canvas.surface_action_is_blocked("bar_dice_roll"), "cold new-round control becomes available after bounded feedback")
	_check(_outcome_guard(app.run_state) == record.get("expected", {}), "cold passive feedback expiry preserves complete settled ledger and accounting")
	await _save_menu()
	var second: Variant = SaveService.new().load_run(SLOT)
	_check(second is RunState and _outcome_guard(second) == record.get("expected", {}), "second normal Save keeps exactly one settled result")
	facts["cold"] = {"cash": app.run_state.bankroll, "rounds": _table().get("rounds_played", 0), "final_dice": record.get("final_dice", []), "early_feedback": early_feedback, "late_blocked": app.game_surface_canvas.surface_action_is_blocked("bar_dice_roll"), "new_paid_inputs": 0}
	facts["completed"] = true


func _idle_tumble(label: String) -> bool:
	var canvas: Variant = app.game_surface_canvas
	var before := _accounting()
	var clock: int = canvas.surface_simulation_time_msec()
	var redraws: int = canvas.perf_draw_frame_total_count
	await create_timer(float(BarDice.TUMBLE_DURATION_MSEC + 150) / 1000.0).timeout
	await _frames(2)
	var elapsed: int = canvas.surface_simulation_time_msec() - clock
	var ready: bool = not canvas.surface_animation_active(BarDice.TUMBLE_CHANNEL) and not canvas.surface_action_is_blocked("bar_dice_resolve") and not canvas.surface_action_is_blocked("bar_dice_shake")
	_check(elapsed >= BarDice.TUMBLE_DURATION_MSEC, "%s surface clock advances autonomously beyond900ms" % label)
	_check(canvas.perf_draw_frame_total_count > redraws, "%s real renderer draws without pointer input" % label)
	_check(_accounting() == before, "%s idle wait does not fund reroll settle or alter rootRNG" % label)
	facts[label] = {"surface_elapsed_msec": elapsed, "channel_elapsed_sec": canvas.surface_elapsed(BarDice.TUMBLE_CHANNEL), "ready": ready, "draws": canvas.perf_draw_frame_total_count - redraws}
	return _check(ready, "%s warm Shake and Settle become actionable after tumble" % label)


func _click(action: String) -> bool:
	await _frames(3)
	var canvas: Variant = app.game_surface_canvas
	var chosen: Dictionary = {}
	for region in canvas.hit_regions:
		var bound: Dictionary = canvas._resolved_surface_action_binding(str(region.get("action", "")), int(region.get("index", -1)))
		if str(bound.get("action", "")) == action: chosen = region; break
	if not _check(not chosen.is_empty(), "real renderer publishes drawn hit region for " + action):
		facts["missing_hit"] = {"action": action, "render_draws": canvas.perf_draw_frame_total_count, "hit_count": canvas.hit_regions.size(), "renderer": canvas.state.get("surface_renderer", ""), "phase": _phase()}
		return false
	var count := actions.size()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = canvas._board_to_screen((chosen.get("rect", Rect2()) as Rect2).get_center())
	canvas._gui_input(event)
	await _frames(3)
	return _check(actions.size() == count + 1 and str(actions[-1].get("action", "")) == action, "drawn input reaches ordinary Host for " + action)


func _save_menu() -> void:
	app.top_menu_button.pressed.emit()
	await _frames(3)
	_check(app._run_menu_is_visible(), "normal Menu opens before Save")
	app.save_foundation_run()
	app.save_service.wait_for_async_save()
	await _frames(2)


func _table() -> Dictionary:
	return app.current_game._table_state_preview(app.run_state, app.run_state.current_environment)


func _ledger(run: RunState) -> Dictionary:
	return run.current_environment.get("game_states", {}).get("bar_dice", {}).get(Authority.LEDGER_KEY, {})


func _session() -> Dictionary:
	return _ledger(app.run_state).get("session", {})


func _phase() -> String:
	return str(_session().get("bar_dice_ritual_phase", ""))


func _accounting() -> Dictionary:
	return {"cash": app.run_state.bankroll, "chips": app.run_state.grand_casino_chips, "rng": str(app.run_state.rng_state), "rounds": _table().get("rounds_played", 0), "result": _wire(_table().get("last_result", {})), "dice": _wire(_session().get("dice", [])), "shake": _session().get("shake_number", 0)}


func _outcome_guard(run: RunState) -> Dictionary:
	var raw := run.to_dict()
	var result: Dictionary = {}
	for key in ["bankroll", "grand_casino_chips", "rng_seed", "rng_state", "debt", "inventory", "story_log", "story_log_archive_count", "game_clock_minutes", "run_spending_score", "numbers_state", "narrative_flags", "run_status"]: result[key] = _wire(raw.get(key))
	result["bar_dice_table"] = _wire(run.current_environment.get("game_states", {}).get("bar_dice", {}))
	return result


func _wire(value: Variant) -> String:
	return Runtime.canonical_fingerprint(JSON.parse_string(JSON.stringify(value)))


func _expectation_path() -> String:
	return OS.get_environment("BTH_WORLD_REENTRY_ROOT").path_join("bar-dice-warm-host-expectation.json")


func _private_roots() -> bool:
	var distribution := OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").replace("\\", "/").simplify_path()
	if not _check(distribution.is_absolute_path() and "native-private-" in distribution, "explicit maintained private native root required"): return false
	var prefix := distribution.get_base_dir().to_lower()
	for key in ["BTH_WORLD_REENTRY_ROOT", "BTH_SAVE_DIR", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_USER_SETTINGS_PATH", "APPDATA"]:
		var path := OS.get_environment(key).replace("\\", "/").simplify_path().to_lower()
		if not _check(path == prefix or path.begins_with(prefix + "/"), "private containment for " + key): return false
	return _check(OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty(), "synthetic test accepts no original save or browser profile")


func _frames(count: int) -> void:
	for frame in range(count): await process_frame


func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok


func _finish() -> void:
	facts["scope"] = "Synthetic practice cup, supported167/$22 configuration and future epoch. Real native Host/model/Canvas drawn hits and injected GUI events; no original R04 save, Web or OS-pointer claim. Cold reads already-settled result only."
	facts["source_sha256"] = {"game": FileAccess.get_sha256("res://scripts/games/bar_dice.gd"), "canvas": FileAccess.get_sha256("res://scripts/ui/game_surface_canvas.gd"), "test": FileAccess.get_sha256("res://scripts/tests/bar_dice_warm_host_check.gd")}
	var result := {"checks": checks, "failures": failures, "facts": facts}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(result, "  ")); file.close()
	print("BAR_DICE_WARM_HOST_RESULT " + JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
