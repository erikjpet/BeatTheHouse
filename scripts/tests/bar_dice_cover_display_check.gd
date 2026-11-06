extends "res://scripts/tests/bar_dice_reveal_save_restore_check.gd"

# BTH061-BAR-DICE-COVER-DISPLAY-001. Fresh supported Practice only: no Save,
# Continue, Call, settlement, original fixture, clock rewrite or outcome choice.
# The existing screen-builder factory constructs this Canvas subclass before
# its first use. Only the label observer differs; normal drawing, processing,
# input, audio and pause ownership remain inherited and enabled.
const COVER_SEED := "BTH061-BAR-DICE-COVER-DISPLAY-001"
const COVER_SLOT := "bar_dice_cover_display"


class LabelCaptureCanvas extends "res://scripts/ui/game_surface_canvas.gd":
	var cov_draw_count: int = 0
	var latest_cov: Dictionary = {}

	func surface_label(text: String, pos: Vector2, font_size: int, color: Color) -> void:
		if text.begins_with("COV ") and pos.is_equal_approx(Vector2(344, 56)):
			cov_draw_count += 1
			var projection: Dictionary = state.get("bar_dice_ritual_projection", {})
			var money: Dictionary = projection.get("money", {})
			latest_cov = {
				"text_argument": text,
				"font_size": font_size,
				"process_frame": Engine.get_process_frames(),
				"draw_count": cov_draw_count,
				"phase": str(state.get("bar_dice_ritual_phase", "")),
				"ante": int(state.get("active_stake", -1)),
				"flat_present": [state.has("covered_total"), state.has("at_risk_total"), state.has("returned_stake")],
				"flat": [int(state.get("covered_total", -1)), int(state.get("at_risk_total", -1)), int(state.get("returned_stake", -1))],
				"projection": [int(money.get("covered_total", -1)), int(money.get("at_risk_total", -1)), int(money.get("returned_stake", -1))],
			}
		super.surface_label(text, pos, font_size, color)


func _initialize() -> void:
	stage = "warm"
	private_root = OS.get_environment("BTH_BAR_DICE_COVER_PRIVATE_ROOT").replace("\\", "/").simplify_path().trim_suffix("/")
	if not _private_paths(): _finish(); return
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = MainScene.instantiate()
	app.set("show_game_library_launcher", true)
	app.set("autosave_slot_id", COVER_SLOT)
	app.set("GameSurfaceCanvasScript", LabelCaptureCanvas)
	root.add_child(app)
	await _frames(8)
	app._settle_script_prewarm_before_runtime()
	if not _check(_inside(ProjectSettings.globalize_path(app.save_service.run_save_path(COVER_SLOT))), "Actual Cover diagnostic slot is private"):
		await _close(); return
	if not _check(not FileAccess.file_exists(app.save_service.run_save_path(COVER_SLOT)), "Fresh diagnostic slot has no prior save"):
		await _close(); return
	await _cover_case()
	await _close()


func _cover_case() -> void:
	app.open_game_test_menu()
	await _frames(2)
	if not _check(app.game_test_generation_overrides_text != null, "Supported Practice configuration exists"): return
	app.game_test_seed_input.text = COVER_SEED
	app.game_test_bankroll_input.value = 94
	app.game_test_stake_floor_input.value = 6
	app.game_test_stake_ceiling_input.value = 6
	app.game_test_generation_overrides_text.text = JSON.stringify({"environment": {"archetype_id": "bar", "kind": "casino", "economic_profile": {"stake_floor": 6, "stake_ceiling": 6, "game_stake_floor_overrides": {}, "game_stake_ceiling_overrides": {}}}})
	var started: Dictionary = app.start_game_test_session("bar_dice")
	if not _check(bool(started.get("ok", false)), "One supported fresh Practice fixture starts"): return
	await _frames(8)
	if not _check(app.game_surface_canvas is LabelCaptureCanvas, "Normal screen builder constructed the observing Canvas before use"): return
	if not _check(bool(app.dev_game_test_mode) and app.run_state.bankroll == 94 and _ints(_table(app.run_state.to_dict()).get("stake_ladder", [])) == [6], "Actual fresh Practice has cash94 and authored ante6"): return
	_connect_canvas()
	facts["boundaries"] = []
	facts["display_server"] = DisplayServer.get_name()
	var initial_account: Dictionary = _guard(app.run_state.to_dict()).account
	if not await _trace("initial", "agree_wager"): return
	for step: Array in [["bar_dice_roll", "cover"], ["bar_dice_ack_cover", "shake"], ["bar_dice_shake", "shake"], ["bar_dice_shake", "shake"], ["bar_dice_resolve", "throw"], ["bar_dice_throw", "reveal"]]:
		if not await _click(str(step[0])): return
		if not await _trace(str(step[0]), str(step[1])): return
		if str(step[1]) == "shake":
			if not await _idle_tumble(): return
	if not _check(_phase() == "reveal" and app.run_state.bankroll == 94 and int(_table(app.run_state.to_dict()).get("rounds_played", -1)) == 0, "Diagnostic ends on the same unfunded Reveal without Call or Save"): return
	if not _check(_guard(app.run_state.to_dict()).account == initial_account, "All ordinary unfunded cup controls preserve account and root RNG"): return
	facts["completed"] = failures.is_empty()


func _trace(label: String, expected_phase: String) -> bool:
	var protected_before: Dictionary = _guard(app.run_state.to_dict()).account
	var ui: Dictionary = app._current_game_surface_ui_state()
	var table: Dictionary = app.current_game._table_state_preview(app.run_state, app.run_state.current_environment)
	var module_state: Dictionary = app.current_game.surface_state(app.run_state, app.run_state.current_environment, ui)
	var active_ante: int = int(module_state.get("active_stake", -1))
	var authority: Dictionary = app.current_game._bar_dice_ritual_authority(app.run_state, app.run_state.current_environment, table, ui, active_ante, table.get("last_result", {}))
	var host_snapshot: Dictionary = app._game_view_snapshot()
	var canvas: Variant = app.game_surface_canvas
	var before_draws: int = canvas.cov_draw_count
	# Observe ordinary queued redraws only. No manual _draw, forced projection
	# publication, process disabling, clock assignment or detached text substitute.
	for frame in range(12):
		await process_frame
		if canvas.cov_draw_count > before_draws and str(canvas.latest_cov.get("phase", "")) == expected_phase: break
	var retained: Dictionary = canvas.realtime_surface_state()
	var draw: Dictionary = canvas.latest_cov.duplicate(true)
	var entry: Dictionary = {
		"label": label,
		"expected_phase": expected_phase,
		"authority": {"phase_input": str(ui.get("bar_dice_ritual_phase", "")), "cover": int(authority.get("covered_total", -1)), "risk": int(authority.get("at_risk_total", -1)), "returned": int(authority.get("returned_stake", -1))},
		"module": _visible_totals(module_state),
		"host_snapshot": _visible_totals(host_snapshot),
		"retained_canvas": _visible_totals(retained),
		"actual_draw": draw,
		"new_actual_draw": canvas.cov_draw_count > before_draws,
		"canvas_processing": canvas.is_processing(),
		"account_and_root_rng_equal": _guard(app.run_state.to_dict()).account == protected_before,
	}
	facts.boundaries.append(entry)
	if not _check(bool(entry.account_and_root_rng_equal), label + " model/text observation preserves account and root RNG"): return false
	if not _check(canvas.cov_draw_count > before_draws and str(draw.get("phase", "")) == expected_phase, label + " actual Canvas draw delivered COV text (otherwise rendering fixture limit)"): return false
	var covered: int = 0 if expected_phase == "agree_wager" else 6
	var expected_totals: Array = [covered, covered, 0]
	if not _check(int(authority.get("covered_total", -1)) == covered and int(authority.get("at_risk_total", -1)) == covered, label + " authority emits the expected unfunded cover/risk"): return false
	for boundary: String in ["module", "host_snapshot", "retained_canvas"]:
		var observed: Dictionary = entry[boundary]
		if not _check(str(observed.phase) == expected_phase and int(observed.ante) == 6 and observed.flat == expected_totals and observed.projection == expected_totals, label + " " + boundary + " retains exact cover/risk/returned values"): return false
	var text: String = str(draw.get("text_argument", ""))
	if not _check(draw.get("flat", []) == expected_totals and text.contains("COV $%d" % covered) and text.contains("RISK $%d" % covered) and text.contains("RET $0"), label + " actual renderer passes exact cover/risk text to normal Canvas drawing"): return false
	return _check(canvas.is_processing(), label + " normal autonomous Canvas processing remains live")


func _visible_totals(value: Dictionary) -> Dictionary:
	var projection: Dictionary = value.get("bar_dice_ritual_projection", {})
	var money: Dictionary = projection.get("money", {})
	return {
		"phase": str(value.get("bar_dice_ritual_phase", "")),
		"ante": int(value.get("active_stake", -1)),
		"pot": int(value.get("pot_meter", -1)),
		"flat_present": [value.has("covered_total"), value.has("at_risk_total"), value.has("returned_stake")],
		"flat": [int(value.get("covered_total", -1)), int(value.get("at_risk_total", -1)), int(value.get("returned_stake", -1))],
		"projection": [int(money.get("covered_total", -1)), int(money.get("at_risk_total", -1)), int(money.get("returned_stake", -1))],
	}


func _finish() -> void:
	facts["scope"] = "Fresh supported Practice cash94/ante6; actual MainScene screen-builder Canvas factory with surface_label-only observation, real renderer hit-region callbacks, no Call/Save/Continue or financial settlement. Authority/module/host snapshot/retained Canvas/actual draw-text trace. No original state, cold/closing/Web or raster-pixel interpretation claim. Native shutdown outcome remains separately recorded by owned runner."
	facts["actions"] = actions
	facts["blocked"] = blocks
	facts["financial_calls"] = 0
	facts["save_inputs"] = 0
	facts["source_sha256"] = {}
	for path: String in ["res://scripts/tests/bar_dice_cover_display_check.gd", "res://scripts/games/bar_dice.gd", "res://scripts/ui/foundation_action_view_model.gd", "res://scripts/ui/game_surface_canvas.gd", "res://scripts/core/bar_dice_ritual_projection.gd"]:
		facts.source_sha256[path.get_file()] = FileAccess.get_sha256(path)
	var result: Dictionary = {"checks": checks, "failures": failures, "facts": facts}
	var output: String = OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty() and not private_root.is_empty() and _inside(output):
		var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(result, "  ")); file.close()
	print("BAR_DICE_COVER_DISPLAY_RESULT " + JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
