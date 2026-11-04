extends SceneTree

# Disposable generated tables only. Commands and accepted actions use the real
# sealed Foundation host. Clock inputs select real timing windows; no wheel,
# grade, receipt, authority companion or original R07 state is supplied.
# Run producer, then --draft-cold, then --cold in the SAME isolated native root.
const Game := preload("res://scripts/games/roulette.gd")
const Host := preload("res://scripts/ui/foundation_main.gd")
const Authority := preload("res://scripts/core/blackjack_action_authority.gd")
const Journal := preload("res://scripts/ui/run_journal_view_model.gd")
const Runtime := preload("res://scripts/core/scenario_sequence_runtime.gd")
const LEGACY := {"type": "game_action", "game_id": "roulette", "action_id": "spin_roulette", "bankroll_delta": -7, "environment_archetype_id": "grand_casino"}
const CHIP := 14
const START_MSEC := 100000

var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {"normal": [], "auxiliary": [], "cold": [], "seed_selection": [], "diagnostics": [], "story_additions": [], "original_profiles_used": false}
var references: Array = []
var private_root := ""
var library: ContentLibrary
var completed := false


func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	if not _private_roots(): _finish(); return
	library = ContentLibrary.new()
	library.load(false)
	if OS.get_cmdline_user_args().has("--cold"):
		_cold()
	elif OS.get_cmdline_user_args().has("--draft-cold"):
		_draft_cold()
	else:
		for currency in ["cash", "chips"]:
			for spec in ["loss", "win", "zero"]:
				if OS.get_cmdline_user_args().has("--baseline") and (currency != "cash" or spec != "loss"): continue
				_normal_case(currency, spec)
		if not OS.get_cmdline_user_args().has("--baseline"):
			for currency in ["cash", "chips"]:
				_wheel_read(currency, false)
				_wheel_read(currency, true)
				_past_post(currency)
			_draft()
			_write_json(_reference_path(), references)
		completed = true
	_finish()


func _fixture(currency: String, seed_text: String, hot: bool = false) -> Dictionary:
	var game := Game.new()
	game.setup(library.game("roulette"), library)
	var run := RunState.new()
	run.start_new(seed_text)
	run.bankroll = 33
	run.grand_casino_chips = 42
	run.baseline_luck = 0
	run.story_log = [LEGACY.duplicate(true)]
	var venue := "grand_casino" if currency == "chips" else "bar"
	var installed := run.set_environment({"id": "roulette_journal_" + venue, "archetype_id": venue, "kind": "casino", "game_ids": ["roulette"], "economic_profile": {"stake_floor": CHIP, "stake_ceiling": 100}, "security_profile": {"strictness": "low"}, "game_states": {}})
	if not bool(installed.get("ok", false)): return {}
	if hot: run.add_suspicion("roulette_journal_fixture_preheat", 64, "behavior")
	var table := game.generate_environment_state(run, run.current_environment, run.create_rng("journal_table"))
	run.current_environment["game_states"] = {"roulette": table}
	return {"game": game, "run": run}


func _host(game: RouletteGame, run: RunState) -> Variant:
	var host := Host.new()
	host.current_game = game
	host.game_module_cache = {"roulette": game}
	host.run_state = run
	host.selected_stake = CHIP
	return host


func _targets(game: RouletteGame, run: RunState, spec: String) -> Array:
	var wanted: Array = ["red", "black"] if spec == "zero" else ["red"] if spec == "win" else ["straight"]
	var view := game.surface_state(run, run.current_environment, {"surface_time_msec": START_MSEC})
	var targets: Array = view.get("bet_targets", [])
	var indexes: Array = []
	for kind in wanted:
		for index in range(targets.size()):
			var target: Dictionary = targets[index]
			if str(target.get("type", "")) == kind and (kind != "straight" or (target.get("numbers", []) as Array).has("17")):
				indexes.append(index); break
	return indexes


func _model_ui(game: RouletteGame, run: RunState, spec: String) -> Dictionary:
	var ui := {"selected_chip": CHIP, "surface_time_msec": START_MSEC}
	for index in _targets(game, run, spec):
		ui = game.surface_action_command("roulette_bet", int(index), false, ui, run, run.current_environment).get("ui_state", ui)
	return ui


func _seed(currency: String, spec: String) -> String:
	# Bounded model-only selection on throwaway candidates. Every retained result
	# starts again from the generated fixture and resolves through the host.
	for index in range(64):
		var seed_text := "ROULETTE-JOURNAL-%s-%s-%d" % [currency, spec, index]
		var fixture := _fixture(currency, seed_text)
		if fixture.is_empty(): return ""
		var game: RouletteGame = fixture.game
		var run: RunState = fixture.run
		var result := game._resolve_roulette_proposal_core("spin_roulette", CHIP, run, run.current_environment, run.create_rng(), _model_ui(game, run, spec))
		var net := int(result.get("bankroll_delta", 99999))
		if bool(result.get("ok", false)) and ((spec == "loss" and net == -CHIP) or (spec == "win" and net > 0) or (spec == "zero" and net == 0)):
			facts.seed_selection.append({"currency": currency, "case": spec, "seed": seed_text, "uncommitted_probes": index + 1})
			return seed_text
	return ""


func _stage(host: Variant, spec: String) -> bool:
	var game: RouletteGame = host.current_game
	var run: RunState = host.run_state
	var before := _economy(run)
	var denoms: Array = _table(run).get("chip_denominations", [])
	var indexes := _targets(game, run, spec)
	if not _check(denoms.has(CHIP) and indexes.size() == (2 if spec == "zero" else 1), spec + " generated public targets and14 denomination exist"): return false
	host._sealed_action_host_surface_intent("roulette_chip", denoms.find(CHIP), false, START_MSEC)
	for index in indexes: host._sealed_action_host_surface_intent("roulette_bet", int(index), false, START_MSEC)
	_check(_economy(host.run_state) == before, spec + " actual host selection stages no money RNG clock or journal transaction")
	return _check(_pending_total(host.run_state) == CHIP * indexes.size(), spec + " actual authenticated draft contains exactly requested chips")


func _spin(host: Variant) -> Dictionary:
	var wager := _pending_total(host.run_state)
	var preview_cost: int = host._sealed_action_host_preview_wager_cost("spin_roulette", CHIP)
	host._sealed_action_host_surface_intent("roulette_spin", 0, false, START_MSEC)
	var command: Dictionary = host._sealed_action_host_surface_intent("roulette_spin", 0, false, START_MSEC)
	var delivery: Dictionary = command.get("_sealed_action_host_delivery", {})
	var nominal_stake := int(delivery.get("stake", -1))
	# The delivery binds the selected denomination. The module separately prices
	# the complete authenticated layout; two14 chips cost28 despite nominal14.
	_check(not delivery.is_empty() and nominal_stake == CHIP, "two ordinary SPIN inputs seal selected fourteen-unit denomination")
	_check(preview_cost == wager, "host prices the entire authenticated draft independently of selected denomination")
	return _resolve_command(host, command, "spin_roulette", "spin")


func _resolve_command(host: Variant, command: Dictionary, action: String, label: String) -> Dictionary:
	var delivery: Dictionary = command.get("_sealed_action_host_delivery", {})
	_check(not delivery.is_empty() and str(delivery.get("action_id", "")) == action, label + " normal command supplies matching authentic delivery")
	var result: Dictionary = host._sealed_action_host_resolve_intent(action, int(delivery.get("stake", -1)), delivery, command.get("_sealed_action_host_prepared", {}))
	# Only public result diagnostics and numeric cost are retained. No delivery,
	# authority ledger, companion, key, profile or prepared candidate is emitted.
	facts.diagnostics.append({"case": label, "ok": result.get("ok", false), "error_code": result.get("error_code", ""), "message": result.get("message", ""), "command_resolves": command.get("resolve", false), "has_delivery": not delivery.is_empty(), "nominal_stake": delivery.get("stake", -1)})
	return result


func _normal_case(currency: String, spec: String) -> void:
	var seed_text := _seed(currency, spec)
	if not _check(not seed_text.is_empty(), currency + " " + spec + " bounded natural seed exists"): return
	var fixture := _fixture(currency, seed_text)
	var host: Variant = _host(fixture.game, fixture.run)
	if not _stage(host, spec): host.free(); return
	var before := _protected(host.run_state)
	var result := _spin(host)
	var run: RunState = host.run_state
	if _check(bool(result.get("ok", false)) and bool(result.get(Authority.HOST_COMMITTED_KEY, false)), currency + " " + spec + " real host accepts one natural spin"):
		var net := _assert_action(run, result, before, currency, currency + " " + spec)
		_check((net == -CHIP if spec == "loss" else net > 0 if spec == "win" else net == 0), currency + " " + spec + " host reproduces selected natural outcome")
		_check(_pending_total(run) == 0 and int(_table(run).get("spin_count", 0)) == 1, currency + " " + spec + " one paid spin consumes its draft")
		if currency == "cash" and spec == "loss": _check(run.bankroll == 19, "reported fourteen-unit loss shape remains cash33 to19")
		_guards(host, result, "spin_roulette", CHIP * (2 if spec == "zero" else 1), currency + " " + spec)
		if not OS.get_cmdline_user_args().has("--baseline"): _save(host.run_state, "roulette_journal_%s_%s" % [currency, spec])
		facts.normal.append({"currency": currency, "case": spec, "net": net, "stake": result.get("roulette_total_wager", 0), "number": result.get("roulette_winning_number", ""), "cash": run.bankroll, "chips": run.grand_casino_chips, "rows": run.story_log.size()})
	host.free()


func _wheel_read(currency: String, security: bool) -> void:
	var fixture := _fixture(currency, "ROULETTE-JOURNAL-READ-%s-%s" % [currency, str(security)], security)
	var host: Variant = _host(fixture.game, fixture.run)
	var before := _protected(host.run_state)
	var armed: Dictionary = host._sealed_action_host_surface_intent("roulette_read_wheel", 0, false, START_MSEC)
	var challenge: Dictionary = armed.get("ui_state", {}).get("wheel_read_challenge", {})
	if not _check(not challenge.is_empty(), currency + " wheel read arms a generated timing challenge"): host.free(); return
	var input_msec := int(challenge.get("target_msec", START_MSEC)) + (int(challenge.get("meter_period_msec", 1400)) / 2 if security else 0)
	var command: Dictionary = host._sealed_action_host_surface_intent("roulette_read_wheel", 0, false, input_msec)
	var result := _resolve_command(host, command, "read_wheel_bias", currency + " wheel read " + str(security))
	if _check(bool(result.get("ok", false)), currency + " timed wheel read commits through real host"):
		var net := _assert_action(host.run_state, result, before, currency, currency + " wheel read")
		_check(net < 0 if security else net == 0, currency + " wheel read records security debit or explicit no-charge zero")
		_check(str(result.get("skill_grade", "")) == ("blown" if security else "perfect"), currency + " wheel read grade follows generated timing marker")
		_guards(host, result, "read_wheel_bias", 0, currency + " wheel read")
		_save(host.run_state, "roulette_journal_read_%s_%s" % [currency, "security" if security else "zero"])
		facts.auxiliary.append({"currency": currency, "action": "read_wheel_bias", "security": security, "net": net})
	host.free()


func _past_post(currency: String) -> void:
	var fixture := _fixture(currency, "ROULETTE-JOURNAL-PAST-" + currency, true)
	var host: Variant = _host(fixture.game, fixture.run)
	if not _stage(host, "loss"): host.free(); return
	var original_history_size: int = host.run_state.story_log.size()
	var initial := _spin(host)
	if not _check(bool(initial.get("ok", false)), currency + " late-chip prerequisite is a real paid spin"): host.free(); return
	var original_net := int(_action_row(host.run_state, initial, original_history_size).get("bankroll_delta", 0))
	var resolved := int(_table(host.run_state).get("last_result", {}).get("resolved_at_msec", 0))
	var before := _protected(host.run_state)
	var at := resolved + 5600
	var armed: Dictionary = host._sealed_action_host_surface_intent("roulette_past_post", 0, false, at)
	var challenge: Dictionary = armed.get("ui_state", {}).get("past_post_challenge", {})
	if not _check(not challenge.is_empty(), currency + " actual payout window arms late chip"): host.free(); return
	var command: Dictionary = host._sealed_action_host_surface_intent("roulette_past_post", 0, false, at)
	var result := _resolve_command(host, command, "past_post", currency + " late chip")
	if _check(bool(result.get("ok", false)), currency + " legitimate timed late chip commits"):
		var net := _assert_action(host.run_state, result, before, currency, currency + " late chip")
		_check(str(result.get("skill_grade", "")) == "perfect" and net > 0, currency + " late chip uses its actual perfect timing payoff")
		_check(original_net != 0 and int(_action_row(host.run_state, result, before.history.size()).get("currency_delta", 99999)) != original_net + net, currency + " late-chip receipt excludes the previous spin net")
		_check(not str(result.get("security_message", "")).is_empty(), currency + " hot late-chip case retains existing security consequence")
		_guards(host, result, "past_post", CHIP, currency + " late chip")
		_save(host.run_state, "roulette_journal_past_" + currency)
		facts.auxiliary.append({"currency": currency, "action": "past_post", "original_net": original_net, "current_net": net})
	host.free()


func _assert_action(run: RunState, result: Dictionary, before: Dictionary, currency: String, label: String) -> int:
	var net := run.grand_casino_chips - int(before.chips) if currency == "chips" else run.bankroll - int(before.cash)
	_check(run.bankroll == int(before.cash) if currency == "chips" else run.grand_casino_chips == int(before.chips), label + " unrelated wallet remains exact")
	var old_size: int = before.history.size()
	_check(run.story_log.slice(0, old_size) == before.history, label + " prior complete story prefix remains exact")
	var action_rows: Array = []
	var event_rows: Array = []
	for entry in run.story_log.slice(old_size):
		if str(entry.get("type", "")) == "game_action": action_rows.append(entry)
		else: event_rows.append(entry)
	_check(action_rows.size() == 1 and str(action_rows[0].get("game_id", "")) == "roulette" and str(action_rows[0].get("action_id", "")) == str(result.get("action_id", "")), label + " appends exactly one matching Roulette action receipt")
	# A large table win legitimately earns a separate invitation AFTER its game
	# receipt. Assert that causal row rather than treating the last row as a wager.
	var invitation := bool(result.get("grand_casino_invitation_spawned", false))
	var invitation_rows: Array = []
	var escort_rows: Array = []
	for entry in event_rows:
		if str(entry.get("type", "")) == "grand_casino_invitation_table_win": invitation_rows.append(entry)
		elif str(entry.get("type", "")) == "rourke_rival_escort": escort_rows.append(entry)
	var escort: Dictionary = run.rourke_escort_state
	var new_escort := not str(escort.get("cheater_id", "")).is_empty() and str(escort.get("cheater_id", "")) != str(before.rourke_escort.get("cheater_id", ""))
	_check(event_rows.size() == (1 if invitation else 0) + (1 if new_escort else 0) and invitation_rows.size() == (1 if invitation else 0) and escort_rows.size() == (1 if new_escort else 0), label + " exact independently earned invitation and rival-escort event counts are preserved")
	if invitation and invitation_rows.size() == 1:
		var entry: Dictionary = invitation_rows[0]
		_check(str(entry.get("game_id", "")) == "roulette" and str(entry.get("event_id", "")) == str(result.get("grand_casino_invitation_event_id", "")) and int(entry.get("bankroll_delta", 99999)) == net, label + " distinct invitation row retains exact earned outcome")
	if new_escort and escort_rows.size() == 1:
		var entry: Dictionary = escort_rows[0]
		_check(str(entry.get("event_id", "")) == "rourke_rival_escort" and str(entry.get("cheater_id", "")) == str(escort.get("cheater_id", "")) and str(entry.get("caught_room", "")) == str(escort.get("caught_room", "")) and str(entry.get("environment_id", "")) == str(run.current_environment.get("id", "")) and str(entry.get("environment_archetype_id", "")) == str(run.current_environment.get("archetype_id", "")), label + " rival-escort row exactly matches the newly caught rival and room")
		_check(run.rourke_current_room.is_empty() and run.rourke_current_spot.is_empty() and run.rourke_off_floor_actions == RunState.ROURKE_OFF_FLOOR_ACTIONS and int(escort.get("actions_remaining", 0)) == RunState.ROURKE_OFF_FLOOR_ACTIONS, label + " rival-escort event retains source-defined off-floor consequence")
	facts.story_additions.append({"case": label, "roulette_action_rows": action_rows.size(), "earned_invitation_rows": invitation_rows.size(), "rival_escort_rows": escort_rows.size(), "invitation_spawned": invitation, "new_rival_escort": new_escort})
	_check(int(result.get("chips_delta" if currency == "chips" else "bankroll_delta", 99999)) == net, label + " published settlement equals actual wallet change")
	var row := _action_row(run, result, old_size)
	if not row.is_empty(): _assert_row(run, row, currency, net, label)
	_legacy(run, label)
	return net


func _action_row(run: RunState, result: Dictionary, start: int) -> Dictionary:
	var matches: Array = []
	for entry in run.story_log.slice(start):
		if str(entry.get("type", "")) == "game_action" and str(entry.get("game_id", "")) == "roulette" and str(entry.get("action_id", "")) == str(result.get("action_id", "")): matches.append(entry)
	return matches[0] if matches.size() == 1 else {}


func _assert_row(run: RunState, row: Dictionary, currency: String, net: int, label: String) -> void:
	_check(str(row.get("currency", "")) == currency and row.has("currency_delta") and int(row.get("currency_delta", 99999)) == net, label + " producer freezes currency and exact local net including zero")
	var before := _fingerprint(run)
	_check(Journal._recorded_money_detail_lines(row) == ["%s %+d" % ["Chips" if currency == "chips" else "Bankroll", net]], label + " journal shows one exact account amount")
	for repeat in range(3): Journal._recorded_money_detail_lines(row)
	_check(_fingerprint(run) == before, label + " repeated journal reads preserve full state")


func _legacy(run: RunState, label: String) -> void:
	_check(run.story_log[0] == LEGACY and not run.story_log[0].has("currency") and Journal._recorded_money_detail_lines(run.story_log[0]) == ["Recorded change -7 (currency not recorded)"], label + " legacy unknown-unit row remains unchanged")


func _guards(host: Variant, result: Dictionary, action: String, stake: int, label: String) -> void:
	var before := _fingerprint(host.run_state)
	var receipt: Dictionary = result.get(Authority.HOST_APPLY_RECEIPT_KEY, {})
	var hash_before := Authority.result_fingerprint(result)
	_check(Authority.valid_receipt_with_result_fingerprint(receipt, receipt, str(receipt.get("table_binding", "")), hash_before), label + " unchanged committed receipt authenticates full result")
	var forged := result.duplicate(true)
	var story: Array = forged.get("deltas", {}).get("story_log", [])
	if not story.is_empty():
		story[0]["currency"] = "cash" if str(story[0].get("currency", "")) == "chips" else "chips"
		_check(not Authority.valid_receipt_with_result_fingerprint(receipt, receipt, str(receipt.get("table_binding", "")), Authority.result_fingerprint(forged)), label + " changed story currency fails exact receipt fingerprint")
	var delivery: Dictionary = result.get(Authority.HOST_DELIVERY_KEY, {})
	var replay: Dictionary = host._sealed_action_host_resolve_intent(action, int(delivery.get("stake", stake)), delivery)
	_check(bool(replay.get("ok", false)) and _fingerprint(host.run_state) == before, label + " exact delivery replay returns cached result without settlement")
	var applied := GameModule.apply_result(host.run_state, result.duplicate(true))
	_check(not bool(applied.get("ok", true)) and _fingerprint(host.run_state) == before, label + " consumed receipt cannot apply twice")


func _draft() -> void:
	var fixture := _fixture("cash", _seed("cash", "loss"))
	var host: Variant = _host(fixture.game, fixture.run)
	if _stage(host, "loss"):
		var reference := _save(host.run_state, "roulette_journal_unpaid_draft", false)
		_check(host.run_state.bankroll == 33 and host.run_state.story_log == [LEGACY] and _pending_total(host.run_state) == CHIP, "unpaid draft Save retains cash33 one14 chip and no new receipt")
		_write_json(_draft_path(), reference)
	host.free()


func _draft_cold() -> void:
	var reference: Variant = JSON.parse_string(FileAccess.get_file_as_string(_draft_path()))
	if not _check(reference is Dictionary and not reference.is_empty(), "producer unpaid draft reference exists"): return
	var loaded: Variant = SaveService.new().load_run(str(reference.slot))
	if not _check(loaded is RunState, "independent process officially loads unpaid draft"): return
	_check(JSON.stringify(_protected(loaded)) == str(reference.protected_json) and loaded.bankroll == 33 and loaded.story_log == [LEGACY] and _pending_total(loaded) == CHIP, "draft cold preserves exact saved wallet RNG clock history table and one unpaid chip")
	var game := Game.new()
	game.setup(library.game("roulette"), library)
	var host: Variant = _host(game, loaded)
	var before := _protected(loaded)
	var result := _spin(host)
	if _check(bool(result.get("ok", false)), "cold draft confirms through normal two-input sealed host"):
		var net := _assert_action(host.run_state, result, before, "cash", "cold draft settlement")
		_check(net == -CHIP and host.run_state.bankroll == 19 and _pending_total(host.run_state) == 0, "cold draft14 settles once cash33 to19 and clears layout")
		_guards(host, result, "spin_roulette", CHIP, "cold draft")
		var paid := _save(host.run_state, "roulette_journal_draft_paid", false)
		_write_json(_draft_paid_path(), paid)
		completed = true
	host.free()


func _save(run: RunState, slot: String, retain: bool = true) -> Dictionary:
	var before := _protected(run)
	if not _check(SaveService.new().save_run(run, slot) == OK, "official Save stores " + slot): return {}
	_check(_protected(run) == before, "Save changes no wallets RNG history or table: " + slot)
	var loaded: Variant = SaveService.new().load_run(slot)
	if not _check(loaded is RunState, "fresh official SaveService loads " + slot): return {}
	_check(_persistent_fingerprint(_protected(loaded)) == _persistent_fingerprint(before), "official load preserves full protected state: " + slot)
	var reference := {"slot": slot, "protected_json": JSON.stringify(_protected(loaded)), "lines": _money_lines(loaded)}
	if retain: references.append(reference)
	return reference


func _cold() -> void:
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(_reference_path()))
	var draft_paid: Variant = JSON.parse_string(FileAccess.get_file_as_string(_draft_paid_path()))
	if not _check(expected is Array and expected.size() == 12 and draft_paid is Dictionary and not draft_paid.is_empty(), "six normal six auxiliary and cold-settled draft references exist"): return
	expected.append(draft_paid)
	for reference in expected:
		var loaded: Variant = SaveService.new().load_run(str(reference.slot))
		if not _check(loaded is RunState, "cold official load succeeds: " + str(reference.slot)): continue
		var before := _fingerprint(loaded)
		_check(JSON.stringify(_protected(loaded)) == str(reference.protected_json) and _money_lines(loaded) == reference.lines, "independent cold preserves entire table wallets RNG clocks history and journal lines: " + str(reference.slot))
		_check(_pending_total(loaded) == 0, "cold paid layout remains consumed: " + str(reference.slot))
		_legacy(loaded, str(reference.slot))
		for repeat in range(3): _money_lines(loaded)
		_check(_fingerprint(loaded) == before, "cold readers cannot settle reroll or append rows: " + str(reference.slot))
		facts.cold.append({"slot": reference.slot, "cash": loaded.bankroll, "chips": loaded.grand_casino_chips, "rows": loaded.story_log.size(), "lines": reference.lines})
	completed = true


func _table(run: RunState) -> Dictionary: return run.current_environment.get("game_states", {}).get("roulette", {})
func _pending_total(run: RunState) -> int:
	var total := 0
	for bet in _table(run).get(Authority.LEDGER_KEY, {}).get("session", {}).get("roulette_bets", []): total += int(bet.get("stake", 0))
	return total
func _fingerprint(run: RunState) -> String: return Runtime.content_fingerprint(run.to_dict())
func _persistent_fingerprint(value: Variant) -> String: return Runtime.content_fingerprint(JSON.parse_string(JSON.stringify(value)))
func _reference_path() -> String: return private_root.path_join("roulette-journal-reference.json")
func _draft_path() -> String: return private_root.path_join("roulette-journal-draft-reference.json")
func _draft_paid_path() -> String: return private_root.path_join("roulette-journal-draft-paid-reference.json")
func _economy(run: RunState) -> Dictionary:
	return {"cash": run.bankroll, "chips": run.grand_casino_chips, "rng_seed": str(run.rng_seed), "rng": str(run.rng_state), "clock": run.game_clock_minutes, "simulation_msec": run.simulation_msec, "history": run.story_log.duplicate(true)}
func _protected(run: RunState) -> Dictionary:
	var value := _economy(run)
	value["table"] = _table(run).duplicate(true)
	value["surface_clock"] = run.surface_clock_checkpoint_msec
	value["debt"] = run.debt.duplicate(true)
	value["inventory"] = run.inventory.duplicate(true)
	value["rourke_escort"] = run.rourke_escort_state.duplicate(true)
	value["rourke_room"] = run.rourke_current_room
	value["rourke_spot"] = run.rourke_current_spot
	value["rourke_off_floor_actions"] = run.rourke_off_floor_actions
	return value
func _money_lines(run: RunState) -> Array:
	var lines: Array = []
	for row in run.story_log: lines.append(Journal._recorded_money_detail_lines(row))
	return lines


func _write_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if _check(file != null, "private phase reference opens"):
		file.store_string(JSON.stringify(value, "\t")); file.close()


func _private_roots() -> bool:
	private_root = OS.get_environment("BTH_WORLD_REENTRY_ROOT").replace("\\", "/").simplify_path()
	if not _check(private_root.is_absolute_path() and "native-private-" in private_root, "explicit disposable native root required"): return false
	for key in ["APPDATA", "BTH_DISTRIBUTION_DATA_ROOT", "BTH_SAVE_DIR", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_USER_SETTINGS_PATH"]:
		var path := OS.get_environment(key).replace("\\", "/").simplify_path().to_lower()
		if not _check(path == private_root.to_lower() or path.begins_with(private_root.to_lower() + "/"), "private containment for " + key): return false
	return _check(OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty(), "no original save or browser profile accepted")


func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok


func _finish() -> void:
	_check(completed, "requested phase reaches its final assertion")
	var mode := "cold" if OS.get_cmdline_user_args().has("--cold") else "draft-cold" if OS.get_cmdline_user_args().has("--draft-cold") else "baseline" if OS.get_cmdline_user_args().has("--baseline") else "producer"
	var report := {"id": "BTH-JOURNAL-ROULETTE-CURRENCY-001", "mode": mode, "checks": checks, "failures": failures, "facts": facts, "source_sha256": {"game": FileAccess.get_sha256("res://scripts/games/roulette.gd"), "journal": FileAccess.get_sha256("res://scripts/ui/run_journal_view_model.gd"), "test": FileAccess.get_sha256("res://scripts/tests/roulette_journal_currency_check.gd")}, "fidelity": "Synthetic generated cash and Grand chip tables. Bounded uncommitted model seed selection; retained normal spins, paid zero-net red/black layouts, generated timed wheel reads and perfect late chips use real sealed Foundation Host. Official SaveService unpaid draft cold settlement and independent final cold read. Receipt fingerprint/replay/direct-apply guards and unchanged legacy row. No original R07 save, forced wheel/grade, renderer/Web input or deployed acceptance claim. Late-chip negative/miss grades and new RNG/economy rules are outside this metadata check."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report, "\t")); file.close()
	print("ROULETTE_JOURNAL_CURRENCY_RESULT " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
