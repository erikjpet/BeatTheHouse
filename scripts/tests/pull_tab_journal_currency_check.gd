extends SceneTree

# Owned native practice purchases plus generated production-module fixtures.
# Pull Tabs is not sealed: buy/sort self-apply; redemption is caller-applied ONCE.
# Run producer then --cold in the SAME private root. No original player data.
const Main := preload("res://scripts/ui/foundation_main.gd")
const Game := preload("res://scripts/games/pull_tabs.gd")
const Journal := preload("res://scripts/ui/run_journal_view_model.gd")
const Runtime := preload("res://scripts/core/scenario_sequence_runtime.gd")
const LEGACY := {"type": "game_action", "game_id": "pull_tabs", "bankroll_delta": -7}
class PracticeHost extends Main:
	var venue := "bar"
	func _prewarm_run_ui_after_web_start() -> void: pass
	func _game_test_archetype() -> Dictionary: return library.environment_archetype(venue)
	func _game_test_bankroll() -> int: return 97
var checks := 0
var failures: Array[String] = []
var facts: Array = []
var references: Array = []
var private_root := ""
var library: ContentLibrary
var completed := false
var baseline := false

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	baseline = OS.get_cmdline_user_args().has("--baseline")
	if not _private_roots(): _finish(); return
	library = ContentLibrary.new(); library.load(false)
	if OS.get_cmdline_user_args().has("--cold"):
		_cold()
	else:
		await _host_purchase("cash")
		if not baseline:
			await _host_purchase("chips")
			for currency in ["cash", "chips"]: _model_case(currency)
			_write(_reference_path(), references)
		completed = true
	_finish()

func _host_purchase(currency: String) -> void:
	var app := PracticeHost.new()
	app.venue = "grand_casino" if currency == "chips" else "bar"
	app.continuous_environment_clock_enabled = false; app.script_prewarm_stopping = true
	root.add_child(app); app.set_process(false)
	await process_frame
	app.user_settings.coach_tips_enabled = false
	if not _check(bool(app.start_game_test_session("pull_tabs").get("ok", false)), currency + " ordinary practice opens"):
		app.free(); return
	var run: RunState = app.run_state
	# Funding-only synthetic setup BEFORE the action; no ticket/outcome is changed.
	run.grand_casino_chips = 25; run.story_log.append(LEGACY.duplicate(true))
	var game: PullTabsGame = app.current_game
	var before := _protected(run)
	var price := int(_machine(game, run).get("deals", [])[0].get("price", 0))
	_check(price > 0 and (currency != "cash" or price == 1), currency + " first ticket has positive posted price; cash baseline costs one")
	app._on_game_surface_action("pull_tab_buy", 0, false)
	for frame in range(3): await process_frame
	var machine := _machine(game, run)
	_check(_wallet_delta(run, before, currency) == -price, currency + " native host pays posted price exactly once without cross-wallet funding")
	_check(machine.get("tray_stack", []).size() == 1 and int(machine.get("tickets_sold", 0)) == int(before.machine.get("tickets_sold", 0)) + 1 and _stock(machine) == _stock(before.machine) - 1, currency + " one finite ticket leaves stock for paid unopened tray")
	var rows := _new_rows(run, before.history, "buy_tab")
	if _check(rows.size() == 1, currency + " native purchase appends one action row"): _money(rows[0], currency, -price, currency + " native purchase")
	_legacy(run)
	facts.append({"case": "native practice purchase", "currency": currency, "posted_price": price, "cash": run.bankroll, "chips": run.grand_casino_chips, "paid_tray": machine.get("tray_stack", []).size(), "rows": rows})
	if not baseline: _save(run, "pulltab_journal_" + currency + "_unopened")
	app.save_service.wait_for_async_save()
	root.remove_child(app); app.free()

func _fixture(currency: String, seed_index: int) -> Dictionary:
	var game := Game.new(); game.setup(library.game("pull_tabs"), library)
	var run := RunState.new(); run.start_new("PULLTAB-JOURNAL-%s-%d" % [currency, seed_index])
	run.bankroll = 97; run.grand_casino_chips = 25; run.baseline_luck = 0
	run.story_log = [LEGACY.duplicate(true)]
	var venue := "grand_casino" if currency == "chips" else "bar"
	var env := {"id": "pulltab_journal_" + venue, "archetype_id": venue, "world_node_id": venue, "kind": "casino", "economic_profile": {"stake_floor": 1, "stake_ceiling": 200}, "security_profile": {"strictness": "low"}, "game_ids": ["pull_tabs"], "game_states": {}, "event_ids": [], "lender_hooks": [], "travel_hooks": []}
	# Redemption results carry only room ID. Production generated IDs use the
	# archetype plus numeric visit suffix, which the normal currency router parses.
	if currency == "chips": env["id"] = "grand_casino_1"
	env.game_states = {"pull_tabs": game.generate_environment_state(run, env, run.create_rng("stock"))}
	if not bool(run.set_environment(env).get("ok", false)): return {}
	return {"game": game, "run": run}

func _natural_seed(currency: String) -> int:
	# Throwaway ordinary paid probes select a naturally small winner and loser.
	# Never edit outcomes, tickets, finite stock, RNG, item ownership or grades.
	for index in range(32):
		var fixture := _fixture(currency, index)
		if fixture.is_empty(): return -1
		var game: PullTabsGame = fixture.game
		var run: RunState = fixture.run
		game.resolve_with_context("buy_tab", 1, run, run.current_environment, run.create_rng("buy"), {"pull_tab_deal_index": 2})
		var first: Array = _machine(game, run).get("tray_stack", [])
		if first.size() != 1 or int(first[0].get("payout", 0)) not in [1, 2, 3]: continue
		game.resolve_with_context(Game.PULL_TAB_BUY_SET_ACTION, 0, run, run.current_environment, run.create_rng("batch"), {})
		for ticket in _machine(game, run).get("tray_stack", []):
			if int(ticket.get("payout", 0)) == 0: return index
	return -1

func _model_case(currency: String) -> void:
	var index := _natural_seed(currency)
	if not _check(index >= 0, currency + " bounded natural fixture has winner and loser"): return
	var fixture := _fixture(currency, index)
	var game: PullTabsGame = fixture.game
	var run: RunState = fixture.run
	_check(run.grand_casino_game_uses_chips("pull_tabs", {"id": str(run.current_environment.id)}) == (currency == "chips"), currency + " canonical result room identity selects its actual account")
	var before := _protected(run)
	var bought := game.resolve_with_context("buy_tab", 1, run, run.current_environment, run.create_rng("buy"), {"pull_tab_deal_index": 2})
	_check(bool(bought.get("ok", false)) and _wallet_delta(run, before, currency) == -1, currency + " natural winning purchase pays once through self-applying module")
	var rows := _new_rows(run, before.history, "buy_tab")
	if _check(rows.size() == 1, currency + " model purchase has one row"): _money(rows[0], currency, -1, currency + " model purchase")
	before = _protected(run)
	var batch := game.resolve_with_context(Game.PULL_TAB_BUY_SET_ACTION, 0, run, run.current_environment, run.create_rng("batch"), {})
	rows = _new_rows(run, before.history, Game.PULL_TAB_BUY_SET_ACTION)
	var cost := 0
	for row in rows:
		cost += int(row.get("cost", 0)); _money(row, currency, -int(row.get("cost", 0)), currency + " batch per-ticket row")
	_check(bool(batch.get("ok", false)) and rows.size() == 4 and cost > 4 and _wallet_delta(run, before, currency) == -cost, currency + " four-row batch debits sum once, each receipt retains its own price")
	_check(int(_machine(game, run).get("tickets_sold", 0)) == 5 and _stock(_machine(game, run)) == _stock(before.machine) - 4, currency + " finite batch dispenses exactly four distinct tickets")
	var paid := _protected(run)
	var ui: Dictionary = game.surface_action_command(Game.PULL_TAB_COLLECT_TRAY_ACTION, 0, false, {}, run, run.current_environment).get("ui_state", {})
	var collected := _protected(run)
	game.surface_action_command(Game.PULL_TAB_COLLECT_TRAY_ACTION, 0, false, ui, run, run.current_environment)
	_check(_protected(run) == collected and run.bankroll == paid.cash and run.grand_casino_chips == paid.chips and str(run.rng_state) == paid.rng and run.story_log == paid.history, currency + " collect and repeat collect preserve payment RNG and full history")
	var loser_count := 0
	var ticket_ids: Array = []
	for step in range(5):
		var stack: Array = _machine(game, run).get("ticket_stack", [])
		if not _check(not stack.is_empty(), currency + " collected ticket available to reveal/file"): break
		var ticket: Dictionary = stack[0]
		_check(not ticket_ids.has(str(ticket.get("id", ""))), currency + " physical ticket processed once"); ticket_ids.append(str(ticket.get("id", "")))
		if int(ticket.get("payout", 0)) == 0: loser_count += 1
		before = _protected(run)
		ui = game.surface_action_command("pull_tab_reveal_next", 0, false, ui, run, run.current_environment).get("ui_state", ui)
		game.checkpoint_surface_ui_state(ui, run, run.current_environment)
		_check(run.bankroll == before.cash and run.grand_casino_chips == before.chips and str(run.rng_state) == before.rng and run.story_log == before.history, currency + " reveal exposes existing ticket without debit redraw or row")
		var sorted := game.resolve_with_context(Game.SORT_TICKET_ACTION, 0, run, run.current_environment, run.create_rng("file"), ui)
		rows = _new_rows(run, before.history, Game.SORT_TICKET_ACTION)
		_check(bool(sorted.get("ok", false)) and _wallet_delta(run, before, currency) == 0 and _stock(_machine(game, run)) == _stock(before.machine), currency + " filing consumes ticket custody without payment or stock change")
		if _check(rows.size() == 1, currency + " file appends one zero row"): _money(rows[0], currency, 0, currency + " sort zero")
	_check(loser_count > 0 and _machine(game, run).get("loser_pile", []).size() == loser_count, currency + " naturally losing tabs remain filed")
	before = _protected(run)
	var rng := run.create_rng("redeem")
	var redeemed: Dictionary = game.environment_action_command(Game.REDEEM_HOOK_ID, Game.REDEEM_ACTION_ID, run, run.current_environment, rng).get("result", {})
	var gross := int(redeemed.get("pull_tab_redeemed_payout", 0))
	var net := int(redeemed.get("bankroll_delta", -999))
	# Match Foundation.use_game_environment_hook: apply exactly once. Capture
	# authored local net first; normal routing rewrites physical cash/chip deltas.
	GameModule.apply_result(run, redeemed, rng)
	_check(bool(redeemed.get("ok", false)) and gross > 0 and net == gross and _wallet_delta(run, before, currency) == gross, currency + " normal cash-in credits gross local prize once without subtracting old purchases")
	_check(int(redeemed.get("bankroll_delta", -999)) == (0 if currency == "chips" else gross) and int(redeemed.get("chips_delta", 0)) == (gross if currency == "chips" else 0), currency + " ordinary apply routes redemption to exact physical account")
	rows = _new_rows(run, before.history, Game.REDEEM_ACTION_ID)
	if _check(rows.size() == 1, currency + " cash-in has one action row"): _money(rows[0], currency, net, currency + " redemption local payout")
	var final_state := _protected(run)
	var repeat_rng := run.create_rng("repeat")
	var repeated: Dictionary = game.environment_action_command(Game.REDEEM_HOOK_ID, Game.REDEEM_ACTION_ID, run, run.current_environment, repeat_rng).get("result", {})
	GameModule.apply_result(run, repeated, repeat_rng)
	game.resolve_with_context(Game.SORT_TICKET_ACTION, 0, run, run.current_environment, run.create_rng("repeat_file"), ui)
	_check(_protected(run) == final_state and int(_machine(game, run).get("cashout_count", 0)) == 1 and _machine(game, run).get("winner_pile", []).is_empty(), currency + " empty repeat redeem/file cannot pay append advance RNG or alter piles")
	_legacy(run)
	facts.append({"case": "generated production module API", "currency": currency, "seed": run.seed_text, "tickets": ticket_ids.size(), "losers": loser_count, "batch_cost": cost, "redemption_gross": gross, "redemption_net": net})
	_save(run, "pulltab_journal_" + currency + "_filed_redeemed")

func _money(row: Dictionary, currency: String, amount: int, label: String) -> void:
	_check(str(row.get("currency", "")) == currency and row.has("currency_delta") and int(row.get("currency_delta", -99999)) == amount, label + " freezes account and exact local amount including zero")
	_check(Journal._recorded_money_detail_lines(row) == ["%s %+d" % ["Chips" if currency == "chips" else "Bankroll", amount]], label + " journal renders one explicit amount")
func _new_rows(run: RunState, prefix: Array, action: String) -> Array:
	_check(run.story_log.slice(0, prefix.size()) == prefix, action + " retains complete prior history")
	var rows: Array = []
	for row in run.story_log.slice(prefix.size()):
		if str(row.get("game_id", "")) == "pull_tabs" and str(row.get("action_id", "")) == action: rows.append(row)
	return rows
func _legacy(run: RunState) -> void:
	_check(run.story_log.has(LEGACY) and Journal._recorded_money_detail_lines(LEGACY) == ["Recorded change -7 (currency not recorded)"], "legacy unknown currency remains immutable and unknown")
func _wallet_delta(run: RunState, before: Dictionary, currency: String) -> int:
	_check(run.bankroll == before.cash if currency == "chips" else run.grand_casino_chips == before.chips, currency + " other wallet unchanged")
	return run.grand_casino_chips - int(before.chips) if currency == "chips" else run.bankroll - int(before.cash)
func _machine(game: PullTabsGame, run: RunState) -> Dictionary: return game._read_machine_state(run, run.current_environment)
func _stock(machine: Dictionary) -> int:
	var stock := 0
	for deal in machine.get("deals", []): stock += int(deal.get("remaining", 0))
	return stock
func _protected(run: RunState) -> Dictionary:
	return {"cash": run.bankroll, "chips": run.grand_casino_chips, "rng_seed": str(run.rng_seed), "rng": str(run.rng_state), "clock": run.game_clock_minutes, "simulation_msec": run.simulation_msec, "surface_clock": run.surface_clock_checkpoint_msec, "history": run.story_log.duplicate(true), "history_archive_count": run.story_log_archive_count, "environment_history": run.environment_history.duplicate(true), "heat_history": run.heat_history.duplicate(true), "machine": run.current_environment.get("game_states", {}).get("pull_tabs", {}).duplicate(true), "custody": run.portable_ticket_state("pull_tabs", run.current_environment).duplicate(true), "debt": run.debt.duplicate(true), "inventory": run.inventory.duplicate(true)}
func _lines(run: RunState) -> Array:
	var lines: Array = []
	for row in run.story_log: lines.append(Journal._recorded_money_detail_lines(row))
	return lines
func _save(run: RunState, slot: String) -> void:
	var before := _protected(run)
	if not _check(SaveService.new().save_run(run, slot) == OK, "official private Save: " + slot): return
	_check(_protected(run) == before, "Save is read-only: " + slot)
	var loaded: Variant = SaveService.new().load_run(slot)
	if not _check(loaded is RunState, "fresh official service loads: " + slot): return
	_check(Runtime.content_fingerprint(JSON.parse_string(JSON.stringify(_protected(loaded)))) == Runtime.content_fingerprint(JSON.parse_string(JSON.stringify(before))), "official load preserves full protected state: " + slot)
	references.append({"slot": slot, "protected_json": JSON.stringify(_protected(loaded)), "lines": _lines(loaded)})
func _cold() -> void:
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(_reference_path()))
	if not _check(expected is Array and expected.size() == 4, "four owned warm references exist"): return
	for reference in expected:
		var loaded: Variant = SaveService.new().load_run(str(reference.slot))
		if not _check(loaded is RunState, "independent cold official load: " + str(reference.slot)): continue
		_check(JSON.stringify(_protected(loaded)) == str(reference.protected_json) and _lines(loaded) == reference.lines, "cold preserves FULL history machine stock custody wallets RNG clocks and currency lines: " + str(reference.slot))
		var before := Runtime.content_fingerprint(loaded.to_dict())
		for repeat in range(3): Journal.entry_view_list(loaded, {}); _lines(loaded)
		_legacy(loaded)
		_check(Runtime.content_fingerprint(loaded.to_dict()) == before, "cold read-only journal cannot debit cash in redraw or rewrite legacy rows")
		facts.append({"case": "independent cold", "slot": reference.slot, "cash": loaded.bankroll, "chips": loaded.grand_casino_chips, "history_rows": loaded.story_log.size(), "lines": reference.lines})
	completed = true
func _reference_path() -> String: return private_root.path_join("pulltab-journal-reference.json")
func _write(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if _check(file != null, "owned JSON opens"): file.store_string(JSON.stringify(value, "\t")); file.close()
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
	var report := {"id": "BTH-JOURNAL-PULLTABS-CURRENCY-001", "mode": "cold" if OS.get_cmdline_user_args().has("--cold") else "baseline" if baseline else "producer", "checks": checks, "failures": failures, "facts": facts, "original_profiles_used": false, "fidelity": "Two actual native Foundation practice purchases, funding-only synthetic initial cash97/chips25; two generated production module API cases selected by bounded natural paid probes. Pull Tabs has no sealed receipt authority. Buy/sort self-apply; redemption applies once via caller. Scanner metadata is source-review scope only. Official SaveService producer and separate cold; no Web input, original profile, machine jam, outcome/item changes or forced winnings.", "source_sha256": {"game": FileAccess.get_sha256("res://scripts/games/pull_tabs.gd"), "journal": FileAccess.get_sha256("res://scripts/ui/run_journal_view_model.gd"), "test": FileAccess.get_sha256("res://scripts/tests/pull_tab_journal_currency_check.gd")}}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty(): _write(output, report)
	print("PULL_TAB_JOURNAL_CURRENCY_RESULT " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
