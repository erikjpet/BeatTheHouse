extends SceneTree

# Synthetic generated tables only. Paid working bets are established by normal
# Pass Dice + roll producers, never by editing a saved bet or its provenance.
# The Street sibling adds an explicitly synthetic supported sweep modifier after
# a normal paid line reaches a point. No original profile, Host/Web or cold claim.
const Craps := preload("res://scripts/games/craps.gd")
const Journal := preload("res://scripts/ui/run_journal_view_model.gd")
const Runtime := preload("res://scripts/core/scenario_sequence_runtime.gd")
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {"scope": "Synthetic generated Craps tables; production refund/pass/dispersal producers and journal projection. No original save, Host/Web input or process-cold claim.", "cases": {}}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-") and ProjectSettings.globalize_path("user://").contains("native-private-"), "explicit disposable storage required"):
		_finish(); return
	if not _check(OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty(), "no captured or original browser inputs"):
		_finish(); return
	var library := ContentLibrary.new()
	library.load(false)
	_take_down(library, "cash", "bar", 20, 12, 0)
	_take_down(library, "chips", "grand_casino", 20, 0, 12)
	_take_down(library, "mixed", "grand_casino", 5, 7, 5)
	_pass(library, "cash", "bar", "synthetic_cash_pass", false, "cash")
	_pass(library, "chips", "grand_casino", "grand_casino_401", false, "chips")
	_pass(library, "grand_id_fallback", "", "grand_casino_402", false, "chips")
	_pass(library, "street", "back_alley", "synthetic_street_pass", true, "cash")
	_street_disperse(library)
	_legacy_unknown(library)
	_finish()

func _context(library: ContentLibrary, label: String, archetype: String, environment_id: String, chips: int, street: bool = false) -> Dictionary:
	var run := RunState.new()
	run.start_new("SYNTHETIC-CRAPS-JOURNAL-" + label)
	run.bankroll = 200
	run.grand_casino_chips = chips
	var game := Craps.new()
	game.definition = library.game("craps")
	var environment := {"id": environment_id, "archetype_id": archetype, "game_ids": ["craps"], "economic_profile": {"stake_floor": 5, "stake_ceiling": 100}, "game_states": {}}
	if street: environment["scenario_game_modifiers"] = {"game_hook": "street_craps"}
	var table := game.generate_environment_state(run, environment, run.create_rng("synthetic_table"))
	environment["game_states"] = {"craps": table}
	run.current_environment = environment
	return {"run": run, "game": game, "environment": environment}

func _take_down(library: ContentLibrary, label: String, archetype: String, chips: int, expected_cash: int, expected_chips: int) -> void:
	var context := _context(library, "take_down_" + label, archetype, archetype + "_410", chips)
	var run: RunState = context.run
	var game: CrapsGame = context.game
	var environment: Dictionary = context.environment
	var passed: Dictionary = game.resolve_with_context("pass_craps_dice", 0, run, environment, run.create_rng("pass"), {})
	if not _check(bool(passed.get("ok", false)), label + " normal Pass Dice allows independent number wager"): return
	# Place6 is off on the come-out, so any natural opening roll leaves this paid
	# working bet intact. No dice outcome is selected or replaced by the test.
	var rolled: Dictionary = game.resolve_with_context("roll_craps", 12, run, environment, run.create_rng("paid_place"), {"craps_pending_bets": {"place_6": 12}, "craps_working_on_come_out": false, "surface_time_msec": 100000})
	if not _check(bool(rolled.get("ok", false)), label + " production roll pays one12 Place6 stake"): return
	var table: Dictionary = environment.game_states.craps
	var provenance: Dictionary = table.get("working_bet_funding", {}).get("place_6", {})
	if not _check(int(table.get("working_bets", {}).get("place", {}).get("6", 0)) == 12 and int(provenance.get("cash", -1)) == expected_cash and int(provenance.get("chips", -1)) == expected_chips, label + " paid working provenance records exact original wallet legs"):
		facts.cases[label + "_setup"] = {"errors": rolled.get("message", ""), "provenance": provenance}; return
	var cash_before := run.bankroll
	var chips_before := run.grand_casino_chips
	var roll_count := int(table.get("roll_count", 0))
	var result: Dictionary = game.resolve_with_context("take_down_craps_bet", 0, run, environment, run.create_rng("take_down"), {"craps_take_down_id": "place_6"})
	if not _check(bool(result.get("ok", false)), label + " production Take Down collects paid stake once"): return
	var entry: Dictionary = run.story_log[-1]
	var details := Journal._recorded_money_detail_lines(entry)
	_check(run.bankroll == cash_before + expected_cash and run.grand_casino_chips == chips_before + expected_chips, label + " correct actual cash and chip refunds remain unchanged")
	_check(int(environment.game_states.craps.get("roll_count", 0)) == roll_count and game._working_wager_total(environment.game_states.craps.get("working_bets", {})) == 0, label + " Take Down neither rolls nor leaves paid stake available twice")
	_check(entry.has("cash_delta") and int(entry.get("cash_delta", -1)) == expected_cash, label + " new refund story explicitly records cash leg includingzero")
	_check(entry.has("chips_delta") and int(entry.get("chips_delta", -1)) == expected_chips, label + " new refund story retains exact chip leg includingzero")
	_check(details.has("Bankroll %+d" % expected_cash) and details.has("Chips %+d" % expected_chips) and details.size() == 2, label + " journal displays separate exact wallet legs without summing")
	_read_only(run, label + " refund")
	facts.cases[label + "_take_down"] = {"cash_delta": run.bankroll - cash_before, "chips_delta": run.grand_casino_chips - chips_before, "provenance": provenance, "journal": details}

func _pass(library: ContentLibrary, label: String, archetype: String, environment_id: String, street: bool, currency: String) -> void:
	var context := _context(library, "pass_" + label, archetype, environment_id, 30, street)
	var run: RunState = context.run
	var game: CrapsGame = context.game
	var environment: Dictionary = context.environment
	var cash := run.bankroll
	var chips := run.grand_casino_chips
	var result: Dictionary = game.resolve_with_context("pass_craps_dice", 0, run, environment, run.create_rng("pass"), {})
	if not _check(bool(result.get("ok", false)), label + " production no-wager Pass Dice succeeds"): return
	var entry: Dictionary = run.story_log[-1]
	var details := Journal._recorded_money_detail_lines(entry)
	_check(run.bankroll == cash and run.grand_casino_chips == chips and int(environment.game_states.craps.get("roll_count", -1)) == 0, label + " Pass Dice spends neither wallet and rolls no outcome")
	_check(str(entry.get("currency", "")) == currency and entry.has("currency_delta") and int(entry.get("currency_delta", -1)) == 0, label + " new Pass Dice story records exact zero in routing currency")
	_check(details == [("Chips" if currency == "chips" else "Bankroll") + " +0"], label + " journal labels zero Pass Dice currency")
	_read_only(run, label + " Pass Dice")
	facts.cases[label + "_pass"] = {"expected_currency": currency, "journal": details, "cash": run.bankroll, "chips": run.grand_casino_chips}

func _street_disperse(library: ContentLibrary) -> void:
	var context := _context(library, "street_disperse", "back_alley", "synthetic_street_411", 30, true)
	var run: RunState = context.run
	var game: CrapsGame = context.game
	var environment: Dictionary = context.environment
	for attempt in range(8):
		if int(environment.game_states.craps.get("point", 0)) != 0: break
		var roll: Dictionary = game.resolve_with_context("roll_craps", 10, run, environment, run.create_rng("street_paid_%d" % attempt), {"craps_pending_bets": {"pass_line": 10}, "surface_time_msec": 100000 + attempt * 1000})
		if not _check(bool(roll.get("ok", false)), "Street setup normal paid line roll succeeds"): return
	var table: Dictionary = environment.game_states.craps
	var refund := game._working_wager_total(table.get("working_bets", {}))
	if not _check(int(table.get("point", 0)) != 0 and refund == 10, "bounded normal Street rolls leave one paid10 line at a point"): return
	var cash := run.bankroll
	var chips := run.grand_casino_chips
	var roll_count := int(table.get("roll_count", 0))
	# Explicit synthetic world interruption uses the supported production seam.
	environment.scenario_game_modifiers["sweep_adjacent"] = true
	var result: Dictionary = game.resolve_with_context("roll_craps", 10, run, environment, run.create_rng("street_sweep"), {"craps_pending_bets": {"pass_line": 10}})
	if not _check(bool(result.get("ok", false)) and str(result.get("action_id", "")) == "street_craps_disperse", "production Street pre-roll dispersal returns existing stake"): return
	var entry: Dictionary = run.story_log[-1]
	var details := Journal._recorded_money_detail_lines(entry)
	_check(run.bankroll == cash + refund and run.grand_casino_chips == chips, "Street dispersal returns only paid cash and ignores unpaid pending10")
	_check(int(environment.game_states.craps.get("roll_count", 0)) == roll_count and game._working_wager_total(environment.game_states.craps.get("working_bets", {})) == 0, "Street interruption consumes working stake without a new dice outcome")
	_check(str(entry.get("currency", "")) == "cash" and entry.has("currency_delta") and int(entry.get("currency_delta", -1)) == refund, "new Street refund story records exact cash delta")
	_check(details == ["Bankroll %+d" % refund], "Street journal labels the actual cash refund")
	_read_only(run, "Street dispersal")
	facts.cases["street_disperse"] = {"refund": refund, "cash_delta": run.bankroll - cash, "chips_delta": run.grand_casino_chips - chips, "journal": details}

func _legacy_unknown(library: ContentLibrary) -> void:
	var context := _context(library, "legacy", "grand_casino", "grand_casino_412", 30)
	var run: RunState = context.run
	var legacy := {"type": "game_action", "game_id": "craps", "action_id": "roll_craps", "bankroll_delta": -10}
	run.log_story(legacy)
	var entry: Dictionary = run.story_log[-1]
	_check(Journal._recorded_money_detail_lines(entry) == ["Recorded change -10 (currency not recorded)"], "legacy unknown unit remains unknown even at current Grand table")
	_read_only(run, "legacy unknown")
	_check(not entry.has("currency") and not entry.has("currency_delta") and not entry.has("cash_delta") and not entry.has("chips_delta"), "journal never retroactively stamps historical unknown unit")

func _read_only(run: RunState, label: String) -> void:
	var before := Runtime.content_fingerprint(run.to_dict())
	for repeat in range(3): Journal.entry_view_list(run, {})
	_check(Runtime.content_fingerprint(run.to_dict()) == before, label + " repeated journal projection preserves full run wallets RNG and story")

func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok

func _finish() -> void:
	facts["source_sha256"] = {"game": FileAccess.get_sha256("res://scripts/games/craps.gd"), "journal": FileAccess.get_sha256("res://scripts/ui/run_journal_view_model.gd"), "test": FileAccess.get_sha256("res://scripts/tests/craps_refund_journal_currency_check.gd")}
	var receipt := {"checks": checks, "failures": failures, "facts": facts}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(receipt, "  ")); file.close()
	print("CRAPS_REFUND_JOURNAL_CURRENCY ", JSON.stringify(receipt))
	quit(0 if failures.is_empty() else 1)
