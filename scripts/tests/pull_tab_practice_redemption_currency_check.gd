extends SceneTree

# Real default Practice launcher and Foundation surface/counter-hook handlers.
# This subclass only removes optional background UI prewarming at teardown.
# NO archetype/funding/outcome/RNG overrides, original profiles or forged result.
const Main := preload("res://scripts/ui/foundation_main.gd")
const Journal := preload("res://scripts/ui/run_journal_view_model.gd")
const Runtime := preload("res://scripts/core/scenario_sequence_runtime.gd")
const SLOT := "pulltab_default_practice_redeemed"
const LEGACY := {"type": "game_action", "game_id": "pull_tabs", "bankroll_delta": -7}
class PracticeHost extends Main:
	func _prewarm_run_ui_after_web_start() -> void: pass
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}
var private_root := ""
var app: Variant
var completed := false
var baseline := false

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	baseline = OS.get_cmdline_user_args().has("--baseline")
	if not _private_roots(): _finish(); return
	if OS.get_cmdline_user_args().has("--cold"):
		_cold(); _finish(); return
	app = PracticeHost.new()
	app.continuous_environment_clock_enabled = false; app.script_prewarm_stopping = true
	root.add_child(app); app.set_process(false)
	await process_frame
	app.user_settings.coach_tips_enabled = false
	app.open_game_test_menu()
	if not _check(app.game_test_seed_input != null, "normal Practice seed text control exists"): _finish(); return
	var retained := false
	var price := 0
	var prize := 0
	# Bounded independent ordinary paid Practice sessions. The selected session
	# is retained as played; no ticket, stock, RNG or outcome is rewritten.
	for probe in range(16):
		app.game_test_seed_input.text = "PRACTICE-REDEEM-%d" % probe
		if not _check(bool(app.start_game_test_session("pull_tabs").get("ok", false)), "default Practice launcher opens naturally generated Pull Tabs"): break
		var run: RunState = app.run_state
		if not _check(str(run.current_environment.get("id", "")) == "practice_pull_tabs" and str(run.current_environment.get("archetype_id", "")) == "grand_casino" and run.bankroll == 100000 and run.grand_casino_chips == 0, "unchanged default selector chooses Grand context and100000cash/0chips"): break
		var before := _protected(run)
		price = int(_machine().get("deals", [])[0].get("price", 0))
		app._on_game_surface_action("pull_tab_buy", 0, false)
		await create_timer(0.9).timeout
		var tray: Array = _machine().get("tray_stack", [])
		if not _check(price > 0 and tray.size() == 1 and run.bankroll == int(before.cash) - price and run.grand_casino_chips == 0, "ordinary paid ticket automatically funds exact posted chip price once"): break
		prize = int(tray[0].get("payout", 0))
		if prize > 0 and prize <= 6:
			retained = true
			facts = {"seed": run.seed_text, "paid_probe_count": probe + 1, "environment_id": run.current_environment.id, "archetype_id": run.current_environment.archetype_id, "posted_price": price, "natural_prize": prize, "paid_cash": run.bankroll, "paid_chips": run.grand_casino_chips, "ticket_id": str(tray[0].get("id", ""))}
			break
	if not _check(retained, "bounded unchanged Practice sessions yield a naturally small paid winner"): _finish(); return
	var run: RunState = app.run_state
	run.story_log.append(LEGACY.duplicate(true))
	var paid := _protected(run)
	app._on_game_surface_action("pull_tab_collect_tray", 0, false)
	await create_timer(0.1).timeout
	_check(_machine().get("tray_stack", []).is_empty() and _machine().get("ticket_stack", []).size() == 1, "real Collect moves the one paid ticket into hand")
	app._on_game_surface_action("pull_tab_reveal_next", 0, false)
	await create_timer(1.2).timeout
	app._on_game_surface_action("pull_tab_file_ticket", 0, false)
	await create_timer(0.7).timeout
	_check(_machine().get("winner_pile", []).size() == 1 and _machine().get("ticket_stack", []).is_empty(), "real Reveal/File preserves natural ticket and files one winner")
	_check(run.bankroll == paid.cash and run.grand_casino_chips == paid.chips and int(_machine().get("tickets_sold", 0)) == int(paid.machine.get("tickets_sold", 0)), "collect reveal file never repurchase or credit winnings")
	var before := _protected(run)
	var invoked: bool = app.use_game_environment_hook("pull_tabs", "ticket_redeemer", "redeem_pull_tab_winners")
	var result: Dictionary = app.last_hook_result
	_check(invoked and bool(result.get("ok", false)), "normal Foundation counter hook accepts the real winner")
	_check(run.bankroll == before.cash and run.grand_casino_chips == int(before.chips) + prize, "default Grand Practice redemption credits intended chips once and leaves cash unchanged")
	_check(int(_machine().get("cashout_count", 0)) == 1 and _machine().get("winner_pile", []).is_empty() and _machine().get("redeemed_pile", []).size() == 1 and int(_machine().get("tickets_sold", 0)) == 1, "one real host hook consumes winner exactly once without another ticket")
	_check(run.story_log.slice(0, before.history.size()) == before.history, "redemption preserves FULL prior history")
	var rows: Array = []
	for row in run.story_log.slice(before.history.size()):
		if str(row.get("game_id", "")) == "pull_tabs" and str(row.get("action_id", "")) == "redeem_pull_tab_winners": rows.append(row)
	if _check(rows.size() == 1, "real counter hook appends one redemption row"):
		_check(str(rows[0].get("currency", "")) == "chips" and int(rows[0].get("currency_delta", -1)) == prize and Journal._recorded_money_detail_lines(rows[0]) == ["Chips %+d" % prize], "new redemption journal records exact natural chip prize")
	_legacy(run)
	facts.merge({"cash_before_redeem": before.cash, "chips_before_redeem": before.chips, "cash_after_redeem": run.bankroll, "chips_after_redeem": run.grand_casino_chips, "physical_result_cash": result.get("bankroll_delta", 0), "physical_result_chips": result.get("chips_delta", 0), "result_currency": result.get("currency", ""), "redemption_rows": rows}, true)
	if not baseline:
		var settled := _protected(run)
		app.use_game_environment_hook("pull_tabs", "ticket_redeemer", "redeem_pull_tab_winners")
		_check(not bool(app.last_hook_result.get("ok", true)) and _protected(run) == settled, "real empty counter retry cannot duplicate credit append history change RNG clock stock or piles")
		_save(run)
	completed = true
	_finish()

func _machine() -> Dictionary: return app.current_game._read_machine_state(app.run_state, app.run_state.current_environment)
func _protected(run: RunState) -> Dictionary:
	return {"cash": run.bankroll, "chips": run.grand_casino_chips, "rng_seed": str(run.rng_seed), "rng": str(run.rng_state), "clock": run.game_clock_minutes, "simulation_msec": run.simulation_msec, "surface_clock": run.surface_clock_checkpoint_msec, "history": run.story_log.duplicate(true), "history_archive_count": run.story_log_archive_count, "environment_history": run.environment_history.duplicate(true), "heat_history": run.heat_history.duplicate(true), "machine": run.current_environment.get("game_states", {}).get("pull_tabs", {}).duplicate(true), "custody": run.portable_ticket_state("pull_tabs", run.current_environment).duplicate(true), "debt": run.debt.duplicate(true), "inventory": run.inventory.duplicate(true)}
func _lines(run: RunState) -> Array:
	var lines: Array = []
	for row in run.story_log: lines.append(Journal._recorded_money_detail_lines(row))
	return lines
func _legacy(run: RunState) -> void:
	_check(run.story_log.has(LEGACY) and Journal._recorded_money_detail_lines(LEGACY) == ["Recorded change -7 (currency not recorded)"], "historical untyped row stays immutable and unknown")
func _save(run: RunState) -> void:
	var before := _protected(run)
	if not _check(SaveService.new().save_run(run, SLOT) == OK, "official service saves owned redeemed Practice state"): return
	_check(_protected(run) == before, "Save does not mutate full protected state")
	var loaded: Variant = SaveService.new().load_run(SLOT)
	if not _check(loaded is RunState, "fresh official service reads redeemed Practice state"): return
	_check(Runtime.content_fingerprint(JSON.parse_string(JSON.stringify(_protected(loaded)))) == Runtime.content_fingerprint(JSON.parse_string(JSON.stringify(before))), "official reload preserves FULL history custody stock wallets RNG and clocks")
	_write(_reference_path(), {"protected_json": JSON.stringify(_protected(loaded)), "lines": _lines(loaded), "facts": facts})
func _cold() -> void:
	var reference: Variant = JSON.parse_string(FileAccess.get_file_as_string(_reference_path()))
	if not _check(reference is Dictionary and not reference.is_empty(), "retained producer reference exists"): return
	var loaded: Variant = SaveService.new().load_run(SLOT)
	if not _check(loaded is RunState, "independent cold official load succeeds"): return
	_check(JSON.stringify(_protected(loaded)) == str(reference.protected_json) and _lines(loaded) == reference.lines, "independent cold preserves FULL history custody stock wallets RNG clocks and journal lines")
	facts = reference.facts
	_check(loaded.bankroll == int(facts.cash_before_redeem) and loaded.grand_casino_chips == int(facts.chips_before_redeem) + int(facts.natural_prize), "cold retained payout remains exactly one intended chip credit")
	var before := Runtime.content_fingerprint(loaded.to_dict())
	for repeat in range(3): Journal.entry_view_list(loaded, {}); _lines(loaded)
	_legacy(loaded)
	_check(Runtime.content_fingerprint(loaded.to_dict()) == before, "cold read-only journal never pays rewrites legacy rows or mutates save")
	completed = true
func _reference_path() -> String: return private_root.path_join("pulltab-practice-redemption-reference.json")
func _write(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if _check(file != null, "owned output opens"): file.store_string(JSON.stringify(value, "\t")); file.close()
func _private_roots() -> bool:
	private_root = OS.get_environment("BTH_WORLD_REENTRY_ROOT").replace("\\", "/").simplify_path()
	if not _check(private_root.is_absolute_path() and "native-private-" in private_root, "explicit disposable native root required"): return false
	for key in ["APPDATA", "BTH_DISTRIBUTION_DATA_ROOT", "BTH_SAVE_DIR", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_USER_SETTINGS_PATH"]:
		var path := OS.get_environment(key).replace("\\", "/").simplify_path().to_lower()
		if not _check(path == private_root.to_lower() or path.begins_with(private_root.to_lower() + "/"), "private containment: " + key): return false
	return _check(OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty(), "original player and browser profiles excluded")
func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok
func _finish() -> void:
	_check(completed, "bounded requested phase completes")
	var report := {"id": "BTH-PULLTABS-PRACTICE-REDEEM-CURRENCY-001", "mode": "cold" if OS.get_cmdline_user_args().has("--cold") else "baseline" if baseline else "producer", "checks": checks, "failures": failures, "facts": facts, "fidelity": "Native default Foundation Practice launcher via ordinary seed text field, surface actions and use_game_environment_hook. Test subclass suppresses only optional background prewarm; no venue, funding, ticket, RNG, outcome, item or scenario overrides. Up to16 independent paid natural Practice probes retain one small winner. Hook performs the sole production apply; no manual routing or extra apply. Official private SaveService and independent cold; no original profile or Web-input claim.", "source_sha256": {"game": FileAccess.get_sha256("res://scripts/games/pull_tabs.gd"), "journal": FileAccess.get_sha256("res://scripts/ui/run_journal_view_model.gd"), "test": FileAccess.get_sha256("res://scripts/tests/pull_tab_practice_redemption_currency_check.gd")}}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty(): _write(output, report)
	if app != null:
		app.save_service.wait_for_async_save()
		if app.get_parent() != null: app.get_parent().remove_child(app)
		app.free()
	print("PULL_TAB_PRACTICE_REDEMPTION_CURRENCY_RESULT " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
