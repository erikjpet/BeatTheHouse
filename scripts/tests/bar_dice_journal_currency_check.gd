extends SceneTree

# Synthetic, disposable five-unit tables. Seed selection uses uncommitted
# model commands; every retained round/press goes through the existing sealed
# Foundation Host and its real apply_result receipt. No supplied dice or seals,
# original R07 profile, renderer/OS-pointer/Web path or paid replay is claimed.
const Game := preload("res://scripts/games/bar_dice.gd")
const Host := preload("res://scripts/ui/foundation_main.gd")
const Authority := preload("res://scripts/core/blackjack_action_authority.gd")
const Journal := preload("res://scripts/ui/run_journal_view_model.gd")
const Runtime := preload("res://scripts/core/scenario_sequence_runtime.gd")
const LEGACY := {"type": "game_action", "game_id": "bar_dice", "action_id": "roll", "bankroll_delta": -7, "environment_archetype_id": "grand_casino"}
const STAKE := 5

var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {"cases": [], "seed_selection": [], "cold": [], "zero_scope": "Ordinary loss/carry costs positive ante; win is at least1; Press has nonzero risk. No ordinary zero control or item/scenario fixture was invented.", "original_profiles_used": false}
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
			for spec in ["lose", "win", "press_lose", "press_win"]:
				if OS.get_cmdline_user_args().has("--baseline") and (currency != "cash" or spec != "lose"): continue
				_case(currency, spec)
		var file := FileAccess.open(_reference_path(), FileAccess.WRITE)
		if _check(file != null, "private producer reference opens"):
			file.store_string(JSON.stringify(references, "\t")); file.close()
		completed = true
	_finish()


func _fixture(currency: String, seed_text: String) -> Dictionary:
	var game := Game.new()
	game.setup(library.game("bar_dice"), library)
	var run := RunState.new()
	run.start_new(seed_text)
	run.bankroll = 97
	run.grand_casino_chips = 25
	run.baseline_luck = 0
	run.story_log = [LEGACY.duplicate(true)]
	var venue := "grand_casino" if currency == "chips" else "bar"
	var environment := {"id": "bar_dice_journal_" + venue, "archetype_id": venue, "kind": "casino", "game_ids": ["bar_dice"], "economic_profile": {"stake_floor": STAKE, "stake_ceiling": STAKE}, "game_states": {}}
	# The canonical setter establishes the detached API fixture. Generation owns
	# all dice, seats, rules and ladder; none of those outcomes are overwritten.
	var installed := run.set_environment(environment)
	if not bool(installed.get("ok", false)): return {}
	var table := game.generate_environment_state(run, run.current_environment, run.create_rng("journal_table"))
	run.current_environment["game_states"] = {"bar_dice": table}
	return {"game": game, "run": run}


func _find_seed(currency: String, wanted: String) -> String:
	# Existing foundation tests select a natural clean win before testing Press.
	# Here the bounded search never applies or authenticates a probe result.
	for index in range(128):
		var seed_text := "BAR-DICE-JOURNAL-%s-%d" % [currency, index]
		var fixture := _fixture(currency, seed_text)
		if fixture.is_empty(): return ""
		var game: BarDiceGame = fixture.game
		var run: RunState = fixture.run
		var ui := _probe_cup(game, run)
		var rng := run.create_rng()
		var result: Dictionary = game._resolve_bar_dice_proposal_core("roll", STAKE, run, run.current_environment, rng, ui)
		if not bool(result.get("ok", false)): continue
		var outcome := str(result.get("bar_dice_outcome", ""))
		if (wanted == "lose" and outcome == "lose") or (wanted == "win" and outcome == "win"):
			facts.seed_selection.append({"currency": currency, "wanted": wanted, "seed_text": seed_text, "probes": index + 1}); return seed_text
		if wanted.begins_with("press_") and outcome == "win":
			var press_wins := rng.randi_range(1, 100) <= 46
			if press_wins == (wanted == "press_win"):
				facts.seed_selection.append({"currency": currency, "wanted": wanted, "seed_text": seed_text, "probes": index + 1}); return seed_text
	return ""


func _probe_cup(game: BarDiceGame, run: RunState) -> Dictionary:
	var ui: Dictionary = {"selected_stake_index": 0, "surface_time_msec": 100000}
	for action in ["bar_dice_roll", "bar_dice_ack_cover", "bar_dice_shake", "bar_dice_shake", "bar_dice_resolve", "bar_dice_throw", "bar_dice_reveal", "bar_dice_ack_call"]:
		var command := game.surface_action_command(action, 0, false, ui, run, run.current_environment)
		ui = command.get("ui_state", ui)
	return ui


func _case(currency: String, spec: String) -> void:
	var seed_text := _find_seed(currency, spec)
	if not _check(not seed_text.is_empty(), currency + " " + spec + " has a bounded natural synthetic seed"): return
	var fixture := _fixture(currency, seed_text)
	if not _check(not fixture.is_empty(), currency + " " + spec + " canonical fixture installs"): return
	var game: BarDiceGame = fixture.game
	var run: RunState = fixture.run
	var host := Host.new()
	host.current_game = game
	host.game_module_cache = {"bar_dice": game}
	host.run_state = run
	host.selected_stake = STAKE
	_check(GameModule.presentation_currency_for_game(run, "bar_dice", run.current_environment) == currency and _table(run).get("stake_ladder", []) == [STAKE], currency + " table uses requested account and authored five-unit ante")
	var before := _protected(run)
	var command: Dictionary = {}
	for action in ["bar_dice_stake", "bar_dice_roll", "bar_dice_ack_cover", "bar_dice_shake", "bar_dice_shake", "bar_dice_resolve", "bar_dice_throw", "bar_dice_reveal", "bar_dice_ack_call"]:
		command = host._sealed_action_host_surface_intent(action, 0, false, 100000)
	var delivery: Dictionary = command.get("_sealed_action_host_delivery", {})
	_check(not delivery.is_empty() and int(delivery.get("stake", 0)) == STAKE, currency + " " + spec + " normal cup issues exact authenticated delivery")
	_check(run.bankroll == 97 and run.grand_casino_chips == 25 and run.story_log == before.history, currency + " " + spec + " ritual remains unfunded until Call")
	var result: Dictionary = host._sealed_action_host_resolve_intent("roll", STAKE, delivery, command.get("_sealed_action_host_prepared", {}))
	run = host.run_state
	if not _check(bool(result.get("ok", false)) and bool(result.get(Authority.HOST_COMMITTED_KEY, false)), currency + " " + spec + " round authenticates and commits"):
		host.free(); return
	var round_net := _assert_action(run, result, before, currency, currency + " " + spec + " round")
	_check(int(_table(run).get("rounds_played", 0)) == 1, currency + " " + spec + " exactly one round settled")
	_check(str(result.get("bar_dice_outcome", "")) == ("lose" if spec == "lose" else "win"), currency + " " + spec + " real Host reproduces selected natural outcome")
	if spec == "lose": _check(round_net == -5 and (run.bankroll == 92 if currency == "cash" else run.grand_casino_chips == 20), currency + " loss debits exact5 including reported cash97 to92 shape")
	_duplicate_guards(host, game, run, result, "roll", STAKE, currency + " " + spec + " round")
	var action_net := round_net
	if spec.begins_with("press_"):
		var offer: Dictionary = _table(run).get("last_result", {}).get("press_offer", {})
		var risk := int(offer.get("risk", 0))
		_check(bool(offer.get("available", false)) and risk > 0, currency + " " + spec + " legitimate clean win owns Press offer")
		var before_press := _protected(run)
		var old_cumulative := int(_table(run).get("last_result", {}).get("bankroll_delta", 0))
		result = host._sealed_action_host_resolve_intent("press", risk)
		run = host.run_state
		if _check(bool(result.get("ok", false)) and bool(result.get(Authority.HOST_COMMITTED_KEY, false)), currency + " " + spec + " Press authenticates and commits"):
			action_net = _assert_action(run, result, before_press, currency, currency + " " + spec)
			_check(bool(result.get("bar_dice_press_won", false)) == (spec == "press_win") and action_net == (risk if spec == "press_win" else -risk), currency + " " + spec + " actual Press pays or loses its exact current risk")
			_check(int(_table(run).get("last_result", {}).get("bankroll_delta", 99999)) == old_cumulative + action_net and int(run.story_log.back().get("currency_delta", 99999)) == action_net, currency + " " + spec + " receipt records current action rather than accumulated last result")
			_check(int(_table(run).get("rounds_played", 0)) == 1, currency + " " + spec + " Press never invents another dice round")
			_duplicate_guards(host, game, run, result, "press", risk, currency + " " + spec)
	_save(run, "bar_dice_journal_%s_%s" % [currency, spec])
	facts.cases.append({"currency": currency, "case": spec, "seed_text": seed_text, "cash": run.bankroll, "chips": run.grand_casino_chips, "round_net": round_net, "current_action_net": action_net, "rounds": _table(run).get("rounds_played", 0), "rows": _rows(run).size(), "player_dice": _table(run).get("last_result", {}).get("player_dice", [])})
	host.free()


func _assert_action(run: RunState, result: Dictionary, before: Dictionary, currency: String, label: String) -> int:
	var net := run.grand_casino_chips - int(before.chips) if currency == "chips" else run.bankroll - int(before.cash)
	_check((run.bankroll == int(before.cash) if currency == "chips" else run.grand_casino_chips == int(before.chips)), label + " unrelated wallet remains unchanged")
	_check(run.story_log.size() == before.history.size() + 1 and int(result.get("chips_delta" if currency == "chips" else "bankroll_delta", 99999)) == net, label + " published delta equals one wallet change and exactly one receipt")
	_assert_row(run, run.story_log.back(), currency, net, label)
	_check(run.story_log[0] == LEGACY and Journal._recorded_money_detail_lines(run.story_log[0]) == ["Recorded change -7 (currency not recorded)"], label + " old unknown-unit row remains exact")
	return net


func _assert_row(run: RunState, row: Dictionary, currency: String, net: int, label: String) -> void:
	_check(str(row.get("currency", "")) == currency and row.has("currency_delta") and int(row.get("currency_delta", 99999)) == net, label + " new story records current currency and exact action net")
	var before := _fingerprint(run)
	_check(Journal._recorded_money_detail_lines(row) == ["%s %+d" % ["Chips" if currency == "chips" else "Bankroll", net]], label + " journal shows one exact account and amount")
	for repeat in range(3): Journal._recorded_money_detail_lines(row)
	_check(_fingerprint(run) == before, label + " repeated journal formatting preserves full run")


func _duplicate_guards(host: Variant, game: BarDiceGame, run: RunState, result: Dictionary, action: String, stake: int, label: String) -> void:
	var before := _fingerprint(run)
	var delivery: Dictionary = result.get(Authority.HOST_DELIVERY_KEY, {})
	var replay: Dictionary = host._sealed_action_host_resolve_intent(action, stake, delivery)
	_check(bool(replay.get("ok", false)) and _fingerprint(run) == before, label + " exact delivery replay never settles twice")
	var applied := GameModule.apply_result(run, result.duplicate(true))
	_check(not bool(applied.get("ok", true)) and _fingerprint(run) == before, label + " duplicate direct apply rejects before any state mutation")
	var forged := delivery.duplicate(true)
	forged["stake"] = stake + 1
	var rejected: Dictionary = host._sealed_action_host_resolve_intent(action, stake + 1, forged)
	_check(not bool(rejected.get("ok", true)) and _fingerprint(run) == before, label + " forged delivery rejects without full run mutation")
	var observer := game.resolve_with_context(action, stake, run, run.current_environment, run.create_rng(), {})
	_check(not bool(observer.get("ok", true)) and _fingerprint(run) == before, label + " legacy unsealed resolver cannot publish another settlement")


func _protected(run: RunState) -> Dictionary:
	return {"cash": run.bankroll, "chips": run.grand_casino_chips, "rng_seed": str(run.rng_seed), "rng": str(run.rng_state), "clock": run.game_clock_minutes, "simulation_msec": run.simulation_msec, "surface_clock": run.surface_clock_checkpoint_msec, "history": run.story_log.duplicate(true), "table": _table(run).duplicate(true), "debt": run.debt.duplicate(true), "inventory": run.inventory.duplicate(true)}


func _save(run: RunState, slot: String) -> void:
	var before := _protected(run)
	if not _check(SaveService.new().save_run(run, slot) == OK, "official Save stores " + slot): return
	_check(_protected(run) == before, "Save does not charge or rewrite history: " + slot)
	var loaded: Variant = SaveService.new().load_run(slot)
	if not _check(loaded is RunState, "fresh official SaveService loads " + slot): return
	_check(_persistent_fingerprint(_protected(loaded)) == _persistent_fingerprint(before), "official load preserves ENTIRE table history wallets RNG clocks debt and inventory: " + slot)
	_check(_money_lines(loaded) == _money_lines(run) and loaded.story_log[0] == LEGACY, "official load preserves new units and old unknown row: " + slot)
	references.append({"slot": slot, "protected_json": JSON.stringify(_protected(loaded)), "lines": _money_lines(loaded)})


func _cold() -> void:
	if not _check(FileAccess.file_exists(_reference_path()), "producer reference exists for independent cold process"): return
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(_reference_path()))
	if not _check(expected is Array and expected.size() == 8, "eight cash chip round and Press producer saves exist"): return
	for reference in expected:
		var loaded: Variant = SaveService.new().load_run(str(reference.slot))
		if not _check(loaded is RunState, "independent process officially loads " + str(reference.slot)): continue
		var before := _fingerprint(loaded)
		_check(JSON.stringify(_protected(loaded)) == str(reference.protected_json), "cold ENTIRE table history wallets RNG clocks debt inventory equal producer load: " + str(reference.slot))
		_check(_money_lines(loaded) == reference.lines and loaded.story_log[0] == LEGACY, "cold every new unit and old unknown row remains exact: " + str(reference.slot))
		for repeat in range(3): _money_lines(loaded)
		_check(_fingerprint(loaded) == before, "cold readers cannot reroll settle or append history: " + str(reference.slot))
		facts.cold.append({"slot": reference.slot, "cash": loaded.bankroll, "chips": loaded.grand_casino_chips, "rounds": _table(loaded).get("rounds_played", 0), "rows": _rows(loaded).size(), "lines": _money_lines(loaded)})
	completed = true


func _table(run: RunState) -> Dictionary: return run.current_environment.get("game_states", {}).get("bar_dice", {})
func _fingerprint(run: RunState) -> String: return Runtime.content_fingerprint(run.to_dict())
func _persistent_fingerprint(value: Variant) -> String: return Runtime.content_fingerprint(JSON.parse_string(JSON.stringify(value)))
func _reference_path() -> String: return private_root.path_join("bar-dice-journal-reference.json")


func _rows(run: RunState) -> Array:
	var rows: Array = []
	for row in run.story_log:
		if str(row.get("game_id", "")) == "bar_dice": rows.append(row)
	return rows


func _money_lines(run: RunState) -> Array:
	var lines: Array = []
	for row in run.story_log: lines.append(Journal._recorded_money_detail_lines(row))
	return lines


func _private_roots() -> bool:
	private_root = OS.get_environment("BTH_WORLD_REENTRY_ROOT").replace("\\", "/").simplify_path()
	if not _check(private_root.is_absolute_path() and "native-private-" in private_root, "explicit disposable native root required"): return false
	for key in ["APPDATA", "BTH_DISTRIBUTION_DATA_ROOT", "BTH_SAVE_DIR", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_USER_SETTINGS_PATH"]:
		var path := OS.get_environment(key).replace("\\", "/").simplify_path().to_lower()
		if not _check(path == private_root.to_lower() or path.begins_with(private_root.to_lower() + "/"), "private containment for " + key): return false
	return _check(OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty(), "no original player save or browser profile is accepted")


func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok


func _finish() -> void:
	_check(completed, "requested producer or cold stage reaches final assertion")
	var report := {"id": "BTH-BARDICE-JOURNAL-CURRENCY-001", "mode": "cold" if OS.get_cmdline_user_args().has("--cold") else "producer", "checks": checks, "failures": failures, "facts": facts, "source_sha256": {"game": FileAccess.get_sha256("res://scripts/games/bar_dice.gd"), "journal": FileAccess.get_sha256("res://scripts/ui/run_journal_view_model.gd"), "test": FileAccess.get_sha256("res://scripts/tests/bar_dice_journal_currency_check.gd")}, "fidelity": "Synthetic generated Bar/Grand tables and bounded uncommitted model seed selection. Retained rounds and Press use unchanged sealed Foundation Host normal ritual actions and authentic apply_result; exact replay/forged/direct-apply guards. Official SaveService and independent cold read; no original R07 input, renderer/Web gameplay or deployed acceptance claim."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report, "\t")); file.close()
	print("BAR_DICE_JOURNAL_CURRENCY_RESULT " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
