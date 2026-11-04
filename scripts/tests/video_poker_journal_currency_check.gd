extends SceneTree

# GRAND-VIDEO-POKER-NEW-UNIT-001. All states are disposable synthetic fixtures.
# The practice-host path uses ordinary Deal/Hold/Draw actions. The guaranteed
# outcome matrix supplies explicit cards to the actual module resolver and
# accounting helper; it is not a sealed-host or visual player-path claim.
const Main := preload("res://scripts/ui/foundation_main.gd")
const Video := preload("res://scripts/games/video_poker.gd")
const Journal := preload("res://scripts/ui/run_journal_view_model.gd")

class ClockHost extends Main:
	var test_msec := 100000
	func _environment_simulation_time_msec() -> int: return test_msec
	func _current_game_surface_input_time_msec() -> int: return test_msec
	func _game_test_archetype() -> Dictionary:
		var wanted := "bar" if OS.get_cmdline_user_args().has("--cash") else "grand_casino"
		for value in library.environment_archetypes:
			if str((value as Dictionary).get("id", "")) == wanted:
				return (value as Dictionary).duplicate(true)
		return {}
	func _prepare_game_test_prerequisites(game_id: String, environment: Dictionary) -> void:
		super._prepare_game_test_prerequisites(game_id, environment)
		# Fixture funding before room installation, never a current player save.
		if game_id == "video_poker": run_state.grand_casino_chips = 1000

class OutcomeFixture extends Video:
	var cards: Array = []
	var pick_rank := 9
	func _deal_deck(_run_state: RunState, _state: Dictionary) -> Array:
		return cards.duplicate(true)
	func _double_up_view(_run_state: RunState, _state: Dictionary, _ui: Dictionary, _last_result: Dictionary) -> Dictionary:
		return {"dealer": {"rank": 7, "suit": 0}, "dealer_rank": 7,
			"picks": [{"rank": pick_rank, "suit": 1}], "pick_ranks": [pick_rank]}

var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {"host_draws": [], "matrix": [], "cold": []}
var references: Array = []
var private_root := ""
var currency := "chips"

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	private_root = OS.get_environment("BTH_VP_JOURNAL_TEST_ROOT").replace("\\", "/").trim_suffix("/")
	currency = "cash" if OS.get_cmdline_user_args().has("--cash") else "chips"
	if not _check(not private_root.is_empty() and private_root.is_absolute_path(), "explicit disposable fixture root is required"):
		_finish(); return
	var save_path := SaveService.new().run_save_path("vp_journal_guard").replace("\\", "/")
	if not _check(save_path.to_lower().begins_with(private_root.to_lower() + "/"), "official SaveService is confined to the explicit disposable root"):
		_finish(); return
	if OS.get_cmdline_user_args().has("--cold"):
		_cold()
	else:
		if not OS.get_cmdline_user_args().has("--matrix-only"):
			await _practice_host()
		_matrix()
		FileAccess.open(_reference_path(), FileAccess.WRITE).store_string(JSON.stringify(references, "\t"))
	_finish()

func _practice_host() -> void:
	var app := ClockHost.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	for frame in range(3): await process_frame
	app.set_process(false)
	var opened: Dictionary = app.start_game_test_session("video_poker")
	if not _check(bool(opened.get("ok", false)), "ordinary practice host opens Video Poker"):
		app.free(); return
	_check(GameModule.presentation_currency_for_game(app.run_state, "video_poker", app.run_state.current_environment) == currency, "practice room has requested wager currency")
	for round_index in range(6):
		_sample(app, 100000 + round_index * 10000)
		var cash_before := app.run_state.bankroll
		var chips_before := app.run_state.grand_casino_chips
		var history_before := _video_rows(app.run_state).size()
		app._on_game_surface_action("video_poker_deal", 0)
		for frame in range(12): await process_frame
		_sample(app, app.test_msec + 1000)
		_check(app.run_state.bankroll == cash_before and app.run_state.grand_casino_chips == chips_before, "free opening does not change either wallet")
		var hand: Array = app.game_surface_canvas.state.get("hand", [])
		for index in _normal_holds(hand): app._on_game_surface_action("video_poker_hold", index)
		app._on_game_surface_action("video_poker_draw", 0)
		for frame in range(12): await process_frame
		var result: Dictionary = app.last_game_result.duplicate(true)
		if not _check(bool(result.get("ok", false)) and str(result.get("action_id", "")) == "draw", "one ordinary Draw settles"):
			break
		var expected := int(result.get("chips_delta", 0)) if currency == "chips" else int(result.get("bankroll_delta", 0))
		_check(app.run_state.bankroll == cash_before + (expected if currency == "cash" else 0) and app.run_state.grand_casino_chips == chips_before + (expected if currency == "chips" else 0), "ordinary Draw changes only the correct wallet once")
		_check(_video_rows(app.run_state).size() == history_before + 1, "ordinary Draw records exactly one new game row")
		var entry: Dictionary = _video_rows(app.run_state).back()
		_assert_row(app.run_state, entry, expected, "ordinary host Draw")
		facts.host_draws.append({"round": round_index, "delta": expected, "currency": currency, "row": entry.duplicate(true), "sealed": bool(result.get("sealed_action_authoritative", false))})
		_sample(app, app.test_msec + 2000)
	if app.save_service.async_save_in_flight(): app.save_service.wait_for_async_save()
	app.free()
	await process_frame

func _matrix() -> void:
	var library := ContentLibrary.new()
	library.load(false)
	for action in ["draw", "double_up"]:
		for outcome in ["win", "lose", "push"]:
			var game := OutcomeFixture.new()
			game.setup(library.game("video_poker"), library)
			var run := RunState.new()
			run.start_new("VP-JOURNAL-SYNTHETIC-%s-%s-%s" % [currency, action, outcome])
			run.bankroll = 92
			run.grand_casino_chips = 18
			run.baseline_luck = 0
			var legacy := {"type": "game_action", "game_id": "video_poker", "action_id": "draw", "bankroll_delta": -7}
			run.story_log = [legacy.duplicate(true)]
			var environment := {"id": "grand_casino_004" if currency == "chips" else "bar_004", "archetype_id": "grand_casino" if currency == "chips" else "bar", "kind": "boss" if currency == "chips" else "casino", "game_ids": ["video_poker"], "economic_profile": {"stake_floor": 1, "stake_ceiling": 100}, "security_profile": {}, "game_states": {}}
			var machine: Dictionary = game.generate_environment_state(run, environment, run.create_rng("fixture_machine"))
			machine.merge({"cabinet_id": "jacks_or_better", "variant_id": "jacks_or_better", "multi_hand_count": 1, "paytable_tier_id": "full_pay", "coin_denominations": [{"label": "1c", "credits": 1}], "denomination_index": 0}, true)
			if action == "double_up": machine.last_result = {"double_credits": 5, "double_chain": 0, "win_credits": 5}
			environment.game_states.video_poker = machine
			run.current_environment = environment
			game.cards = _cards([11, 11, 4, 4, 8] if outcome == "win" else ([2, 4, 6, 8, 10] if outcome == "lose" else [11, 11, 4, 7, 9]))
			game.pick_rank = 9 if outcome == "win" else (3 if outcome == "lose" else 7)
			var cash_before := run.bankroll
			var chips_before := run.grand_casino_chips
			# Explicit card fixture reaches the production resolver and apply_result.
			# No action authority validation is bypassed on a player state.
			var result: Dictionary = game.resolve_with_context(action, 1, run, run.current_environment, run.create_rng("fixture_action"), {"holds": [0, 1, 2, 3, 4], "bet_level": 0, "denomination_index": 0, "double_pick": 0, "surface_time_msec": 100000})
			var expected := (1 if outcome == "win" else (-1 if outcome == "lose" else 0)) * (5 if action == "double_up" else 1)
			_check(bool(result.get("ok", false)), "synthetic %s %s resolves" % [action, outcome])
			_check(run.bankroll == cash_before + (expected if currency == "cash" else 0) and run.grand_casino_chips == chips_before + (expected if currency == "chips" else 0), "synthetic %s %s applies exactly the expected one-wallet net" % [action, outcome])
			var game_rows := _video_rows(run)
			if _check(game_rows.size() == 2, "synthetic outcome adds exactly one history row"):
				_assert_row(run, game_rows.back(), expected, "synthetic %s %s" % [action, outcome])
			_check(run.story_log[0] == legacy and not run.story_log[0].has("currency"), "old unstamped history is unchanged")
			_check(Journal._recorded_money_detail_lines(run.story_log[0]) == ["Recorded change -7 (currency not recorded)"], "old unknown unit is not guessed from current venue")
			var slot := "vp_journal_%s_%s_%s" % [currency, action, outcome]
			_save_reference(run, slot)
			facts.matrix.append({"action": action, "outcome": outcome, "currency": currency, "expected_delta": expected, "cash": run.bankroll, "chips": run.grand_casino_chips, "slot": slot})

func _save_reference(run: RunState, slot: String) -> void:
	var before := _protected(run)
	var saves := SaveService.new()
	if not _check(saves.save_run(run, slot) == OK, "official Save stores " + slot): return
	_check(_protected(run) == before, "official Save does not transact or rewrite history: " + slot)
	var loaded: Variant = SaveService.new().load_run(slot)
	if not _check(loaded is RunState, "fresh SaveService loads " + slot): return
	_check(loaded.bankroll == run.bankroll and loaded.grand_casino_chips == run.grand_casino_chips and loaded.rng_state == run.rng_state and loaded.game_clock_minutes == run.game_clock_minutes, "same-process official load preserves wallets, clock and RNG: " + slot)
	_check(_money_lines(loaded) == _money_lines(run), "same-process official load preserves every recorded money line: " + slot)
	_check(not loaded.story_log[0].has("currency"), "official load preserves old unknown unit: " + slot)
	# Reference is captured after the official JSON numeric transport so cold
	# equality compares two real loads, without replacing the save or its keys.
	# Store the exact encoded reference as text; parsing the reference file must
	# not independently convert its integer fields to floating-point numbers.
	references.append({"slot": slot, "protected_json": JSON.stringify(_protected(loaded)), "lines": _money_lines(loaded)})

func _cold() -> void:
	if not _check(FileAccess.file_exists(_reference_path()), "producer reference exists for independent-process cold load"): return
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(_reference_path()))
	if not _check(typeof(expected) == TYPE_ARRAY and expected.size() == 6, "six producer slots exist"): return
	for reference in expected:
		var loaded: Variant = SaveService.new().load_run(str(reference.slot))
		if not _check(loaded is RunState, "independent process officially loads " + str(reference.slot)): continue
		var actual := _protected(loaded)
		_check(JSON.stringify(actual) == str(reference.protected_json), "cold wallets, clock, RNG and complete history match producer load: " + str(reference.slot))
		_check(_money_lines(loaded) == reference.lines, "cold recorded units and amounts match: " + str(reference.slot))
		var before := _protected(loaded)
		for repeat in range(3): _money_lines(loaded)
		_check(_protected(loaded) == before, "cold repeated journal reads never settle again: " + str(reference.slot))
		facts.cold.append({"slot": reference.slot, "cash": loaded.bankroll, "chips": loaded.grand_casino_chips, "lines": _money_lines(loaded)})

func _assert_row(run: RunState, entry: Dictionary, expected: int, label: String) -> void:
	_check(str(entry.get("currency", "")) == currency and int(entry.get("currency_delta", 999)) == expected, label + " records current action currency and net including zero")
	var before := _protected(run)
	var lines: Array = Journal._recorded_money_detail_lines(entry)
	_check(lines == ["%s %+d" % ["Chips" if currency == "chips" else "Bankroll", expected]], label + " journal shows one correct account and amount")
	_check(_protected(run) == before and Journal._recorded_money_detail_lines(entry) == lines, label + " repeated journal formatting is read-only")

func _protected(run: RunState) -> Dictionary:
	return {"cash": run.bankroll, "chips": run.grand_casino_chips, "rng": str(run.rng_state), "rng_seed": str(run.rng_seed), "clock": run.game_clock_minutes, "history": run.story_log.duplicate(true)}

func _money_lines(run: RunState) -> Array:
	var lines: Array = []
	for entry in run.story_log: lines.append(Journal._recorded_money_detail_lines(entry))
	return lines

func _video_rows(run: RunState) -> Array:
	var rows: Array = []
	for entry in run.story_log:
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("type", "")) == "game_action" and str(entry.get("game_id", "")) == "video_poker": rows.append(entry)
	return rows

func _cards(ranks: Array) -> Array:
	var result: Array = []
	for index in range(ranks.size()): result.append({"rank": int(ranks[index]), "suit": index % 4, "deck": 0})
	return result

func _normal_holds(hand: Array) -> Array:
	for a in range(hand.size()):
		for b in range(a + 1, hand.size()):
			if int(hand[a].get("rank", 0)) == int(hand[b].get("rank", 0)): return [a, b]
	for index in range(hand.size()):
		if int(hand[index].get("rank", 0)) == 1 or int(hand[index].get("rank", 0)) >= 11: return [index]
	return []

func _sample(app: ClockHost, msec: int) -> void:
	app.test_msec = msec
	app.game_surface_canvas.surface_simulation_clock_msec = msec
	app.game_surface_canvas.surface_presentation_clock_msec = msec
	app._advance_presented_bankroll()
	app._refresh_financial_hud_if_dirty()
	app._flush_money_feedback()

func _reference_path() -> String: return private_root + "/vp-journal-" + currency + "-reference.json"

func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
	return ok

func _finish() -> void:
	var report := {"id": "GRAND-VIDEO-POKER-NEW-UNIT-001", "currency": currency, "mode": "cold" if OS.get_cmdline_user_args().has("--cold") else "producer", "checks": checks, "failures": failures, "facts": facts,
		"fidelity": "Disposable practice-host Deal/Hold/Draw plus explicit synthetic resolver/card matrix and official SaveService. Independent --cold process is official load and read-only journal; no original player save, visual Web gameplay or normal main-menu Continue is claimed."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty(): FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("VIDEO_POKER_JOURNAL_CURRENCY " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
