extends "res://scripts/tests/bar_dice_reveal_save_restore_check.gd"

# BTH061-BAR-DICE-REVEAL-RESTORE-001: independent CATALOG venue control.
# This is a declared synthetic initial bankroll/clock/scenario/town condition,
# not Practice, normal travel, an original save or a no-forced-clock claim.
# Production generation owns all room/terms/game/outcome/seal construction.
const VENUE_SEED := "BTH061-BAR-DICE-VENUE-TERMS-001"
const OPEN_CLOCK := 23 * 60
const CLOSED_CLOCK := 1440 + 5 * 60 + 30


func _fixture_seed() -> String:
	return VENUE_SEED


func _warm() -> void:
	if not _check(not FileAccess.file_exists(app.save_service.run_save_path(SLOT)) and not FileAccess.file_exists(_expectation_path()), "Venue case requires unused private save/expectation paths"): return
	if not await _prepare_venue(): return
	_connect_canvas()
	# The first generated chip must actually be6. Selection uses its drawn hit,
	# never a ladder/ante/session rewrite or a forced financial result.
	if not await _click("bar_dice_stake"): return
	if not _check(int(_session().get("selected_stake_index", -1)) == 0 and int(app.game_surface_canvas.state.get("active_stake", -1)) == 6, "Drawn first chip selects actual authored index0/six-unit ante"): return
	if not await _click("bar_dice_roll"): return
	if not await _click("bar_dice_ack_cover"): return
	if not await _idle_tumble(): return
	if not _check(_phase() == "shake" and int(_session().get("shake_number", 0)) == 1, "Catalog venue opens one unfunded first Shake"): return
	if not await _save_boundary("venue_shake_control", false): return
	var shake_guard: Dictionary = _guard(app.run_state.to_dict())
	if not _check(app.load_foundation_run(), "Normal Continue loads open-hours venue Shake control"): return
	if not _check(app.enter_game("bar_dice"), "Normal venue reentry restores Shake control"): return
	await _frames(8)
	_connect_canvas()
	if not _compare_host(shake_guard, "Venue Shake Continue"): return
	if not await _idle_tumble(): return
	for number in [2, 3]:
		if not await _click("bar_dice_shake"): return
		if not _check(int(_session().get("shake_number", 0)) == number and _phase() == "shake", "One ordinary remaining Shake advances to %d" % number): return
		if not await _idle_tumble(): return
	var before_ritual: Dictionary = _guard(app.run_state.to_dict())
	if not await _click("bar_dice_resolve"): return
	if not _check(_phase() == "throw", "Catalog Settle presents Throw"): return
	if not await _click("bar_dice_throw"): return
	if not _check(_phase() == "reveal", "Catalog Slam presents Reveal before Lift/Call"): return
	var before_clock: Dictionary = _guard(app.run_state.to_dict())
	if not _check(before_clock.account == before_ritual.account and before_clock.cup.dice == before_ritual.cup.dice, "Warm Settle/Slam preserve unfunded wallet/rootRNG/final dice"): return
	facts["before_closed_clock"] = _economy()
	var minutes_before: int = app.run_state.game_clock_minutes
	if not _check(minutes_before < CLOSED_CLOCK, "Declared clock target is forward and after the venue close"): return
	# Deliberate CONTROLLED CLOCK input through the ordinary core API. No scenario
	# clear/cycle/refresh function is called by this test. Menu/Continue owns that.
	var advanced: Dictionary = app.run_state.advance_game_clock_minutes(CLOSED_CLOCK - minutes_before)
	facts["controlled_clock"] = {"from": minutes_before, "to": app.run_state.game_clock_minutes, "ok": bool(advanced.get("ok", false)), "errors": advanced.get("errors", [])}
	if not _check(bool(advanced.get("ok", false)) and app.run_state.game_clock_minutes == CLOSED_CLOCK, "Ordinary core clock API advances declared fixture to Day2 05:30"): return
	var after_clock: Dictionary = _guard(app.run_state.to_dict())
	facts["after_clock_before_save"] = _economy()
	facts["clock_preservation"] = {"cup_equal": after_clock.cup == before_clock.cup, "account_and_root_rng_equal": after_clock.account == before_clock.account}
	if not _check(after_clock.cup == before_clock.cup and after_clock.account == before_clock.account, "Controlled clock advance preserves accepted cup and wallet/rootRNG"): return
	if not await _save_boundary("reveal", true): return
	facts["after_closed_reveal_save"] = _economy()
	facts["completed"] = true
	facts["warm_paid_calls"] = 0


func _prepare_venue() -> bool:
	app._ensure_full_content_library_loaded()
	if not _check(bool(app._ensure_run_ui_built()), "Actual MainScene run UI builds"): return false
	app.user_settings.coach_tips_enabled = false
	var run: RunState = RunState.new()
	run.start_new(_fixture_seed())
	run.begin_act(1)
	run.bankroll = 94
	var clock: Dictionary = run.advance_game_clock_minutes(OPEN_CLOCK - run.game_clock_minutes)
	if not _check(bool(clock.get("ok", false)) and run.game_clock_minutes == OPEN_CLOCK, "Fresh fixture core clock reaches declared23:00 before any room generation"): return false
	var map_data: Dictionary = WorldMap.new(app.library).build(run, run.create_rng("bar_dice_venue_fixture_world"))
	run.set_world_map(map_data)
	var generator: RunGenerator = RunGenerator.new(app.library)
	var rng: RngStream = run.create_rng("bar_dice_venue_fixture_generation")
	var options: Dictionary = {"scenario_id": "bar_wake", "condition_overrides": {"day_type": "payday", "weather": "clear", "happenings": []}, "depth": 0}
	var node: Dictionary = WorldMap.node_by_id(run.world_map, "bar")
	if not _check(not node.is_empty(), "Fresh shipped WorldMap contains Bar"): return false
	var generated: Dictionary = generator._world_environment_data_for_node(run, run.world_map, node, rng, options)
	if not _check(not generated.is_empty(), "Single production generation constructs catalog Bar Wake/Payday room"): return false
	run.save_rng(rng)
	run.remember_environment_situation_cycle("bar", str(generated.get("environment_situation_cycle_id", "")), "bar_wake")
	var installed: Dictionary = generator._install_environment(run, generated)
	facts["generation"] = {"requested_scenario": "bar_wake", "requested_conditions": options.condition_overrides, "initial_clock": OPEN_CLOCK, "install_ok": bool(installed.get("ok", false)), "errors": installed.get("errors", []), "generation_attempts": 1}
	if not _check(bool(installed.get("ok", false)), "Trusted production boundary installs generated venue"): return false
	app.run_state = run
	app.generator = generator
	app._bind_run_state_presentation_signals()
	app._configure_coach_for_run()
	app._refresh_run_action_service()
	app._sync_presented_bankroll_to_actual()
	app._queue_room_publication_check()
	app._set_current_screen("ENVIRONMENT")
	app._refresh()
	await _frames(12)
	var proof: Dictionary = run.validate_room_action_authority()
	facts["fixture"] = {"seed": _fixture_seed(), "cash": run.bankroll, "clock_minutes": run.game_clock_minutes, "practice": bool(app.dev_game_test_mode), "environment_test": bool(app.dev_environment_test_mode), "authority_ok": bool(proof.get("ok", false)), "authority_errors": proof.get("errors", []), "economy": _economy(), "clock_input": "Explicit controlled core-API initial23:00 and laterDay205:30; not natural elapsed route"}
	if not _check(not bool(app.dev_game_test_mode) and not bool(app.dev_environment_test_mode) and not app._is_environment_test_session() and not run.is_tutorial_run(), "Generated fixture uses real venue owner, no Practice/environment-test/tutorial bypass"): return false
	if not _check(bool(proof.get("ok", false)) and run.bankroll == 94 and str(run.current_environment.get("scenario_id", "")) == "bar_wake", "Catalog identity, wallet94 and room authority survive actual Host publication"): return false
	var economy: Dictionary = run.current_environment.get("economic_profile", {})
	var table: Dictionary = _table(run.to_dict())
	var ladder: Array = table.get("stake_ladder", [])
	facts["generated_terms"] = {"floor": economy.get("stake_floor", -1), "ceiling": economy.get("stake_ceiling", -1), "ladder": ladder.duplicate(), "day_type": run.town_state.day_type()}
	if not _check(int(economy.get("stake_floor", -1)) == 6 and not ladder.is_empty() and int(ladder[0]) == 6, "One declared catalog fixture actually generates floor6 and first ladder ante6; otherwise stop without seed search"): return false
	if not _check(app.enter_game("bar_dice"), "Normal actual Bar Dice entry succeeds"): return false
	await _frames(8)
	return true


func _compare_host(expected: Dictionary, label: String) -> bool:
	if not super._compare_host(expected, label): return false
	var surface: Dictionary = app._current_game_surface_ui_state()
	var rendered: Dictionary = app.game_surface_canvas.state
	var expected_phase: String = str(expected.get("cup", {}).get("phase", ""))
	var expected_dice: String = str(expected.get("cup", {}).get("dice", ""))
	var surface_phase: String = str(surface.get("bar_dice_ritual_phase", ""))
	var rendered_phase: String = str(rendered.get("bar_dice_ritual_phase", ""))
	facts[label]["ui_phase"] = surface_phase
	facts[label]["rendered_phase"] = rendered_phase
	facts[label]["ui_dice_equal"] = _digest(_ints(surface.get("dice", []))) == expected_dice
	facts[label]["economy"] = _economy()
	var equal: bool = surface_phase == expected_phase and rendered_phase == expected_phase and bool(facts[label].ui_dice_equal)
	if not equal and str(facts.first_loss).is_empty(): facts.first_loss = label + ":rendered_or_restored_UI_lost_accepted_cup"
	return _check(equal, label + " retains actual restored UI/rendered phase and exact dice, not only its canonical ledger")


func _economy() -> Dictionary:
	if app == null or app.run_state == null: return {"state": "before_Continue", "ante_block_reason": "not_in_game"}
	return super._economy()


func _finish() -> void:
	facts["source_sha256"] = {"game": FileAccess.get_sha256("res://scripts/games/bar_dice.gd"), "fixture": FileAccess.get_sha256(get_script().resource_path), "base": FileAccess.get_sha256("res://scripts/tests/bar_dice_reveal_save_restore_check.gd")}
	facts["scope"] = "NEW catalog Bar Wake/Payday/clear/no-happenings venue, cash94, supported production WorldMap/RunGenerator/installation and actual MainScene renderer clicks. Explicit CONTROLLED core-clock inputs before generation23:00 and before RevealSaveDay205:30. No Practice bypass, normal-travel/no-clock-advance claim, original storage or outcome edits. Separate cold stage may finish same exact cup once only."
	facts["stage"] = stage
	facts["actions"] = actions
	facts["blocked"] = blocks
	var result: Dictionary = {"checks": checks, "failures": failures, "facts": facts}
	var output: String = OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty() and not private_root.is_empty() and _inside(output):
		var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(result, "  ")); file.close()
	print("BAR_DICE_VENUE_TERMS_RESTORE_RESULT " + JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
