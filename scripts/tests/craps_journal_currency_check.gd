extends SceneTree

# Disposable synthetic fixtures only. The outcome matrix selects a fresh RNG
# seed with the existing rules helper, then the real Craps resolver rolls and
# applies its own result. Host samples use ordinary public chip/bet/throw
# handlers. Neither path reads a player profile or claims visual Web acceptance.
const Main := preload("res://scripts/ui/foundation_main.gd")
const Craps := preload("res://scripts/games/craps.gd")
const Rules := preload("res://scripts/games/craps/craps_rules.gd")
const Journal := preload("res://scripts/ui/run_journal_view_model.gd")
const Runtime := preload("res://scripts/core/scenario_sequence_runtime.gd")
const LEGACY := {"type": "game_action", "game_id": "craps", "action_id": "roll_craps", "bankroll_delta": -7, "environment_archetype_id": "grand_casino"}

class ClockHost extends Main:
	var test_msec := 100000
	var fixture_currency := "chips"
	func _environment_simulation_time_msec() -> int: return test_msec
	func _current_game_surface_input_time_msec() -> int: return test_msec
	func _game_test_bankroll() -> int: return 155
	func _game_test_stake_floor() -> int: return 5
	func _game_test_stake_ceiling() -> int: return 100
	func _game_test_archetype() -> Dictionary:
		var wanted := "grand_casino" if fixture_currency == "chips" else "bar"
		for value in library.environment_archetypes:
			if str(value.get("id", "")) == wanted: return value.duplicate(true)
		return {}
	func _prepare_game_test_prerequisites(game_id: String, environment: Dictionary) -> void:
		super._prepare_game_test_prerequisites(game_id, environment)
		if game_id == "craps":
			run_state.grand_casino_chips = 25
			run_state.baseline_luck = 0
			run_state.story_log = [LEGACY.duplicate(true)]

var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {"matrix": [], "host": [], "cold": [], "rng_controls": []}
var references: Array = []
var private_root := ""
var library: ContentLibrary
var completed := false


func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	if not _private_roots(): _finish(); return
	if OS.get_cmdline_user_args().has("--cold"):
		_cold()
	else:
		library = ContentLibrary.new()
		library.load(false)
		for currency in ["cash", "chips"]:
			_matrix(currency)
			if not OS.get_cmdline_user_args().has("--matrix-only"): await _host_sample(currency)
		var file := FileAccess.open(_reference_path(), FileAccess.WRITE)
		if _check(file != null, "private producer reference opens"):
			file.store_string(JSON.stringify(references, "\t")); file.close()
		completed = true
	_finish()


func _matrix(currency: String) -> void:
	for spec in [{"id": "field_loss", "bets": {"field": 10}, "total": 7, "net": -10}, {"id": "field_win", "bets": {"field": 10}, "total": 9, "net": 10}, {"id": "world_zero", "bets": {"world": 5}, "total": 7, "net": 0}]:
		var fixture := _fixture(currency, str(spec.id))
		var game: GameModule = fixture.game
		var run: RunState = fixture.run
		var passed: Dictionary = game.resolve_with_context("pass_craps_dice", 0, run, run.current_environment, run.create_rng("synthetic_pass"), {})
		_check(bool(passed.get("ok", false)), currency + " synthetic setup passes dice through production resolver")
		_roll_case(game, run, currency, str(spec.id), spec.bets, int(spec.total), int(spec.net))
	var working := _fixture(currency, "paid_working")
	var working_game: GameModule = working.game
	var working_run: RunState = working.run
	_roll_case(working_game, working_run, currency, "working_paid", {"pass_line": 10}, 6, -10)
	_check(int(working_game._table_state_preview(working_run, working_run.current_environment).get("working_bets", {}).get("pass_line", 0)) == 10, currency + " first debit leaves a real paid10 working line")
	_roll_case(working_game, working_run, currency, "working_continuation", {}, 5, 0)
	_roll_case(working_game, working_run, currency, "working_return", {}, 6, 20)
	_check(int(working_game._table_state_preview(working_run, working_run.current_environment).get("working_bets", {}).get("pass_line", -1)) == 0, currency + " returned paid stake is cleared after its20 credit")
	var losing := _fixture(currency, "paid_working_loss")
	var losing_game: GameModule = losing.game
	var losing_run: RunState = losing.run
	_roll_case(losing_game, losing_run, currency, "working_loss_setup", {"pass_line": 10}, 6, -10, false)
	_roll_case(losing_game, losing_run, currency, "working_loss", {}, 7, 0)
	_check(int(losing_game._table_state_preview(losing_run, losing_run.current_environment).get("working_bets", {}).get("pass_line", -1)) == 0, currency + " lost already-paid stake clears without a second wallet debit")


func _fixture(currency: String, label: String) -> Dictionary:
	var game := Craps.new()
	game.setup(library.game("craps"), library)
	var run := RunState.new()
	run.start_new("SYNTHETIC-CRAPS-JOURNAL-%s-%s" % [currency, label])
	run.bankroll = 155
	run.grand_casino_chips = 25
	run.baseline_luck = 0
	run.story_log = [LEGACY.duplicate(true)]
	var archetype := "grand_casino" if currency == "chips" else "bar"
	var environment := {"id": "%s_journal_%s" % [archetype, label], "archetype_id": archetype, "kind": "boss" if currency == "chips" else "casino", "game_ids": ["craps"], "economic_profile": {"stake_floor": 5, "stake_ceiling": 100}, "security_profile": {}, "game_states": {}}
	environment.game_states.craps = game.generate_environment_state(run, environment, run.create_rng("synthetic_table"))
	run.current_environment = environment
	_check(GameModule.presentation_currency_for_game(run, "craps", environment) == currency, currency + " synthetic fixture uses requested account")
	return {"game": game, "run": run}


func _roll_case(game: GameModule, run: RunState, currency: String, label: String, pending: Dictionary, total: int, expected: int, save: bool = true) -> void:
	var table: Dictionary = game._table_state_preview(run, run.current_environment)
	var rng := _rng_for_total(table.get("rules", {}), total)
	var cash := run.bankroll
	var chips := run.grand_casino_chips
	var history := run.story_log.size()
	# The explicit empty draft is important: omitted context permits the legacy
	# stake shorthand to create a fresh Pass/Come wager on continuation.
	var result: Dictionary = game.resolve_with_context("roll_craps", Rules.pending_wager_total(pending), run, run.current_environment, rng, {"craps_pending_bets": pending.duplicate(true), "surface_time_msec": 100000 + history * 10000})
	if not _check(bool(result.get("ok", false)), "%s %s real roll producer accepts synthetic input" % [currency, label]): return
	_check(int(result.get("craps_roll", {}).get("total", 0)) == total, currency + " " + label + " real dice use selected synthetic seed")
	_check(run.bankroll == cash + (expected if currency == "cash" else 0) and run.grand_casino_chips == chips + (expected if currency == "chips" else 0), currency + " " + label + " changes only correct wallet by exact current-roll net")
	_check(run.story_log.size() == history + 1, currency + " " + label + " appends exactly one accepted roll row")
	var entry: Dictionary = run.story_log.back()
	_assert_row(run, entry, currency, expected, label)
	_assert_legacy(run, label)
	if save: _save_reference(run, "craps_journal_%s_%s" % [currency, label])
	facts.matrix.append({"currency": currency, "case": label, "pending": pending, "total": total, "net": expected, "cash": run.bankroll, "chips": run.grand_casino_chips, "row": entry.duplicate(true), "saved": save})


func _rng_for_total(rules: Dictionary, wanted: int) -> RngStream:
	for seed in range(1, 1000):
		var probe := RngStream.new()
		probe.configure(seed)
		if int(Rules.roll_dice(probe, rules).get("total", 0)) != wanted: continue
		var selected := RngStream.new()
		selected.configure(seed)
		facts.rng_controls.append({"seed": seed, "wanted_total": wanted, "scope": "fresh synthetic RNG only; real resolver rolls from reset selected seed"})
		return selected
	_check(false, "bounded existing seed-search helper finds desired synthetic total")
	return RngStream.new()


func _host_sample(currency: String) -> void:
	var app := ClockHost.new()
	app.fixture_currency = currency
	app.show_game_library_launcher = true
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	for frame in range(3): await process_frame
	app.set_process(false)
	var opened: Dictionary = app.start_game_test_session("craps")
	if not _check(bool(opened.get("ok", false)), currency + " ordinary practice Host opens Craps"):
		app.free(); return
	_sample(app)
	app._on_game_surface_action("craps_pass_dice", 0)
	for frame in range(3): await process_frame
	_answer_table(app)
	app.test_msec += 10000
	_sample(app)
	var targets: Array = app.game_surface_canvas.state.get("bet_targets", [])
	var field_index := -1
	for index in range(targets.size()):
		if str(targets[index].get("id", "")) == "field": field_index = index
	var chips: Array = app.game_surface_canvas.state.get("chip_denominations", [])
	var chip_index := chips.find(5)
	if not _check(field_index >= 0 and chip_index >= 0, currency + " production Host exposes Field and five-unit chip"):
		app.free(); return
	app._on_game_surface_action("craps_chip", chip_index)
	app._on_game_surface_action("craps_bet", field_index)
	app._on_game_surface_action("craps_bet", field_index)
	_check(app._current_game_surface_ui_state().get("craps_pending_bets", {}).get("field", 0) == 10, currency + " ordinary chip/bet handlers stage exactly10 Field")
	var cash := app.run_state.bankroll
	var before_chips := app.run_state.grand_casino_chips
	var history := app.run_state.story_log.size()
	app._on_game_surface_action("craps_throw", 0)
	for frame in range(8): await process_frame
	var result: Dictionary = app.last_game_result
	if _check(bool(result.get("ok", false)) and str(result.get("action_id", "")) == "roll_craps", currency + " ordinary Host Throw accepts one naturally-generated roll"):
		var net := int(result.get("chips_delta", 0)) if currency == "chips" else int(result.get("bankroll_delta", 0))
		_check(app.run_state.bankroll == cash + (net if currency == "cash" else 0) and app.run_state.grand_casino_chips == before_chips + (net if currency == "chips" else 0), currency + " Host changes correct wallet once")
		_check(app.run_state.story_log.size() == history + 1, currency + " Host appends exactly one new roll history row")
		_assert_row(app.run_state, app.run_state.story_log.back(), currency, net, "ordinary Host Field")
		_assert_legacy(app.run_state, "ordinary Host Field")
		_save_reference(app.run_state, "craps_journal_%s_host" % currency)
		facts.host.append({"currency": currency, "net": net, "total": result.get("craps_roll", {}).get("total", 0), "cash": app.run_state.bankroll, "chips": app.run_state.grand_casino_chips})
	app.save_service.wait_for_async_save()
	app.free()
	await process_frame


func _sample(app: ClockHost) -> void:
	app.game_surface_canvas.surface_simulation_clock_msec = app.test_msec
	app.game_surface_canvas.surface_presentation_clock_msec = app.test_msec
	app.last_game_surface_realtime_refresh_msec = 0
	app._advance_game_surface_realtime_state()


func _answer_table(app: ClockHost) -> void:
	for entry in app._pending_talk_entries(): app._on_talk_dock_choice_requested(str(entry.get("event_id", "")), "ignore")


func _assert_row(run: RunState, entry: Dictionary, currency: String, expected: int, label: String) -> void:
	_check(str(entry.get("currency", "")) == currency and entry.has("currency_delta") and int(entry.get("currency_delta", 99999)) == expected, currency + " " + label + " records action currency and exact net includingzero")
	var before := _protected(run)
	var lines: Array = Journal._recorded_money_detail_lines(entry)
	_check(lines == ["%s %+d" % ["Chips" if currency == "chips" else "Bankroll", expected]], currency + " " + label + " journal displays one exact recorded account and net")
	for repeat in range(3): _check(Journal._recorded_money_detail_lines(entry) == lines, label + " repeated journal line is stable")
	_check(_protected(run) == before, label + " all repeated journal reads leave complete protected state unchanged")


func _assert_legacy(run: RunState, label: String) -> void:
	_check(run.story_log[0] == LEGACY and not run.story_log[0].has("currency"), label + " old unknown Craps row remains exact")
	_check(Journal._recorded_money_detail_lines(run.story_log[0]) == ["Recorded change -7 (currency not recorded)"], label + " old unknown unit is never inferred from current venue")


func _protected(run: RunState) -> Dictionary:
	return {"cash": run.bankroll, "chips": run.grand_casino_chips, "rng_seed": str(run.rng_seed), "rng": str(run.rng_state), "clock": run.game_clock_minutes, "history": run.story_log.duplicate(true), "table": run.current_environment.get("game_states", {}).get("craps", {}).duplicate(true)}


func _save_reference(run: RunState, slot: String) -> void:
	var before := _protected(run)
	if not _check(SaveService.new().save_run(run, slot) == OK, "official Save stores " + slot): return
	_check(_protected(run) == before, "Save never transacts or rewrites history: " + slot)
	var loaded: Variant = SaveService.new().load_run(slot)
	if not _check(loaded is RunState, "fresh official SaveService reads " + slot): return
	_check(loaded.bankroll == run.bankroll and loaded.grand_casino_chips == run.grand_casino_chips and loaded.rng_state == run.rng_state and loaded.game_clock_minutes == run.game_clock_minutes, "official load preserves wallets RNG and clock: " + slot)
	_check(_persistent_fingerprint(_protected(loaded)) == _persistent_fingerprint(before), "official load preserves complete history and entire Craps table: " + slot)
	_check(_money_lines(loaded) == _money_lines(run), "official load preserves every recorded unit line: " + slot)
	_assert_legacy(loaded, slot)
	# Capture an exact official-load reference, so the independent cold process
	# compares two real codec loads without constructing or replacing a save.
	references.append({"slot": slot, "protected_json": JSON.stringify(_protected(loaded)), "lines": _money_lines(loaded)})


func _cold() -> void:
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(_reference_path()))
	if not _check(expected is Array and expected.size() in [14, 16], "producer reference retains14 matrix slots plus optionaltwo Host slots"): return
	for reference in expected:
		var loaded: Variant = SaveService.new().load_run(str(reference.slot))
		if not _check(loaded is RunState, "independent process officially loads " + str(reference.slot)): continue
		var actual := _protected(loaded)
		_check(JSON.stringify(actual) == str(reference.protected_json), "cold wallets RNG clock complete history and table match producer load: " + str(reference.slot))
		_check(_money_lines(loaded) == reference.lines, "cold recorded units match every saved row: " + str(reference.slot))
		for repeat in range(3): _money_lines(loaded)
		_check(_protected(loaded) == actual, "cold repeated reader never settles or changes protected state: " + str(reference.slot))
		_assert_legacy(loaded, str(reference.slot))
		facts.cold.append({"slot": reference.slot, "cash": loaded.bankroll, "chips": loaded.grand_casino_chips, "lines": _money_lines(loaded)})
	completed = true


func _money_lines(run: RunState) -> Array:
	var lines: Array = []
	for entry in run.story_log: lines.append(Journal._recorded_money_detail_lines(entry))
	return lines


func _persistent_fingerprint(value: Variant) -> String:
	return Runtime.content_fingerprint(JSON.parse_string(JSON.stringify(value)))


func _reference_path() -> String: return private_root.path_join("craps-journal-reference.json")


func _private_roots() -> bool:
	private_root = OS.get_environment("BTH_WORLD_REENTRY_ROOT").replace("\\", "/").simplify_path()
	if not _check(private_root.is_absolute_path() and "native-private-" in private_root, "explicit maintained disposable native root required"): return false
	for key in ["BTH_DISTRIBUTION_DATA_ROOT", "BTH_SAVE_DIR", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_USER_SETTINGS_PATH", "APPDATA"]:
		var path := OS.get_environment(key).replace("\\", "/").simplify_path().to_lower()
		if not _check(path == private_root.to_lower() or path.begins_with(private_root.to_lower() + "/"), "private containment for " + key): return false
	return _check(OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty(), "synthetic regression accepts no actual save or browser profile")


func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok


func _finish() -> void:
	_check(completed, "requested producer or cold stage reaches final assertion")
	var report := {"id": "BTH-CRAPS-JOURNAL-CURRENCY-001", "mode": "cold" if OS.get_cmdline_user_args().has("--cold") else "producer", "checks": checks, "failures": failures, "facts": facts, "source_sha256": {"game": FileAccess.get_sha256("res://scripts/games/craps.gd"), "journal": FileAccess.get_sha256("res://scripts/ui/run_journal_view_model.gd"), "test": FileAccess.get_sha256("res://scripts/tests/craps_journal_currency_check.gd")}, "fidelity": "Synthetic cash/chip practice Host actions plus seed-selected real resolver/apply_result matrix. Full old history/working table retained. Official SaveService and independent cold reads; no original R04 save, visual Web or normal main-menu Continue claim."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report, "\t")); file.close()
	print("CRAPS_JOURNAL_CURRENCY_RESULT " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
