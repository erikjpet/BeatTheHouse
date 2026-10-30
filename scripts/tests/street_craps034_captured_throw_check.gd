extends "res://scripts/tests/scenario_venue_cycle_captured_check.gd"

const Fingerprint := preload("res://scripts/core/game_ritual_runtime.gd")
const ActionView := preload("res://scripts/ui/foundation_action_view_model.gd")

class StakeHost:
	extends RefCounted
	var run_state: RunState
	var current_game: GameModule
	func _presented_bankroll() -> int: return run_state.bankroll

func _run() -> void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-"), "explicit private Street Craps root required"):
		_finish(); return
	var mode := OS.get_environment("BTH_STREET034_CASE")
	if not _check(mode in ["preview", "roll", "restore"], "explicit read-only/one-roll/cold case required"):
		_finish(); return
	if mode != "restore": _install(OS.get_environment("BTH_CAPTURED_FIXTURE"))
	var reference: RunState = SaveService.new().load_run("foundation_ui_autosave")
	if not _check(reference != null, "official copied NF10/NF12 or prospective save loads"):
		_finish(); return
	var expected := _protected_paid(reference)
	root.size = Vector2i(1280, 720)
	var app := Host.new(); app.continuous_environment_clock_enabled = false; app.script_prewarm_stopping = true
	root.add_child(app)
	for frame in range(3): await process_frame
	if not _check(app.load_foundation_run(), "ordinary copied Continue without replaying the paid trip"):
		app.queue_free(); await process_frame; _finish(); return
	app.set_process(false)
	_check(_protected_paid(app.run_state) == expected, "Continue preserves the entire paid table, story, wallet, debt and RNG")
	if not _check(app.enter_game("craps"), "normal entry opens the preserved Craps object"):
		app.queue_free(); await process_frame; _finish(); return
	for frame in range(3): await process_frame
	var run: RunState = app.run_state
	var table: Dictionary = app.current_game._table_state_preview(run, run.current_environment)
	_check(str(table.get("variant_id", "")) == "street_craps" and str(table.get("table_name", "")) == "Rain Gutter Circle", "captured street table identity")
	_check(int(table.get("table_minimum", 0)) == 2 and int(table.get("table_maximum", 0)) == 18 and int(run.current_environment.get("economic_profile", {}).get("stake_ceiling", -1)) == 0, "existing table2..18 coexists with unchanged zero generic Alley ceiling")
	if mode == "restore":
		_check(int(table.get("roll_count", 0)) == 1, "independent cold process retains exactly the one committed throw")
		_check(_protected_paid(run) == expected, "cold game entry does not settle, debit or roll again")
	else:
		_check(run.bankroll == 50 and run.grand_casino_chips == 0 and run.suspicion.level == 1 and run.debt.is_empty(), "genuine pre-roll cash50/Heat1/no debt")
		_check(int(table.get("roll_count", -1)) == 0 and int(table.get("point", -1)) == 0 and table.get("working_bet_funding", {}).is_empty(), "no existing roll, point or funded wager")
		_action_view_contract(app)
		if mode == "roll": await _one_visible_roll(app)
		else: _check(_protected_paid(run) == expected, "all action/stake previews leave the genuine state unchanged")
	facts["mode"] = mode
	facts["protected"] = _protected_paid(app.run_state)
	facts["craps_source_sha256"] = FileAccess.get_sha256("res://scripts/games/craps.gd")
	facts["test_sha256"] = FileAccess.get_sha256("res://scripts/tests/street_craps034_captured_throw_check.gd")
	facts["fidelity"] = "Genuine copied NF10 or NF12 save. Read-only stake projection matrix uses separately labelled synthetic cash/casino clones. Roll mode uses current rendered mouse hit targets for $2, Don't Pass and exactly one THROW, followed by one same-frame duplicate rejection check. No travel, forced dice/RNG, reward inference, outcome search or clock injection. Ordinary environment clock disabled for native observation; not real-time Web acceptance."
	app.save_service.wait_for_async_save(); app.queue_free(); await process_frame; _finish()

func _action_view_contract(app: Host) -> void:
	var run: RunState = app.run_state
	var before := Fingerprint.canonical_fingerprint(run.to_save_snapshot())
	var generic := GameModule.new(); generic.setup(app.current_game.definition, app.library)
	var inherited: Dictionary = generic.actions(run, run.current_environment)
	var provided: Dictionary = app.current_game.actions(run, run.current_environment)
	var stake_host := StakeHost.new(); stake_host.run_state = run; stake_host.current_game = app.current_game
	var old_range := ActionView.stake_range_from_action_view(stake_host, inherited)
	var new_range := ActionView.stake_range_from_action_view(stake_host, provided)
	_check(int(inherited.get("stake_ceiling", -1)) == 0 and not bool(old_range.get("has_valid", true)), "source control: inherited generic zero ceiling rejects every host stake")
	_check(int(provided.get("stake_floor", 0)) == 2 and int(provided.get("stake_ceiling", 0)) == 18 and bool(new_range.get("has_valid", false)) and int(new_range.get("min", 0)) == 2 and int(new_range.get("max", 0)) == 18, "real host action projection accepts the existing table2..18 limits")
	_check(provided.get("legal_actions") == inherited.get("legal_actions") and provided.get("cheat_actions") == inherited.get("cheat_actions"), "table-limit presentation does not add or remove game actions")
	_check(Fingerprint.canonical_fingerprint(run.to_save_snapshot()) == before, "generic/table/host stake projections are full-state read-only")
	var prior_selection := app.selected_stake
	_check(not app.set_selected_stake(1) and not app.set_selected_stake(19), "host rejects stakes below2 and above18 without resolving a wager")
	_check(app.set_selected_stake(2) and app.set_selected_stake(18), "host accepts both existing table limit endpoints as UI-only selections")
	app.set_selected_stake(prior_selection)
	_check(Fingerprint.canonical_fingerprint(run.to_save_snapshot()) == before, "stake boundary selections do not debit, fund, log or advance RNG")
	for cash in [0, 1, 2, 7, 50]:
		var clone := RunState.new(); clone.from_dict(run.to_save_snapshot()); clone.bankroll = cash
		var clone_before := Fingerprint.canonical_fingerprint(clone.to_save_snapshot())
		stake_host.run_state = clone
		var clone_view: Dictionary = app.current_game.actions(clone, clone.current_environment)
		var clone_range := ActionView.stake_range_from_action_view(stake_host, clone_view)
		_check(int(clone_view.get("stake_floor", 0)) == 2 and int(clone_view.get("stake_ceiling", -1)) == mini(18, cash) and bool(clone_range.get("has_valid", false)) == (cash >= 2), "synthetic funds boundary does not enable an unaffordable table stake: " + str(cash))
		_check(Fingerprint.canonical_fingerprint(clone.to_save_snapshot()) == clone_before, "cash-cap preview does not alter its synthetic state")
	# Synthetic casino contrast only: keep its generic action semantics exactly.
	var casino := RunState.new(); casino.from_dict(run.to_save_snapshot())
	casino.current_environment = run.current_environment.duplicate(true)
	casino.current_environment["scenario_game_modifiers"] = {}
	casino.current_environment.game_states.craps["variant_id"] = "casino_craps"
	casino.current_environment.economic_profile["stake_floor"] = 5
	casino.current_environment.economic_profile["stake_ceiling"] = 30
	var casino_before := Fingerprint.canonical_fingerprint(casino.to_save_snapshot())
	_check(app.current_game.actions(casino, casino.current_environment) == generic.actions(casino, casino.current_environment), "nonstreet casino action view remains exactly inherited")
	_check(Fingerprint.canonical_fingerprint(casino.to_save_snapshot()) == casino_before, "casino contrast is read-only")
	facts["stake_projection"] = {"generic_ceiling": inherited.get("stake_ceiling"), "table_floor": provided.get("stake_floor"), "table_ceiling": provided.get("stake_ceiling"), "host_has_valid": new_range.get("has_valid")}

func _one_visible_roll(app: Host) -> void:
	var run: RunState = app.run_state
	var original: Array = run.story_log.duplicate(true)
	var original_protected := _protected_paid(run)
	var before_other := _non_craps_games(run.to_save_snapshot())
	var denominations: Array = app.game_surface_canvas.state.get("chip_denominations", [])
	var chip_index := denominations.find(2)
	if not _check(chip_index >= 0, "visible $2 denomination exists"): return
	if not _click_current_target(app, "craps_chip", chip_index): return
	for frame in range(2): await process_frame
	var targets: Array = app.game_surface_canvas.state.get("bet_targets", [])
	var dont_index := -1
	for i in range(targets.size()):
		if str(targets[i].get("id", "")) == "dont_pass": dont_index = i
	if not _check(dont_index >= 0, "visible Don't Pass target exists"): return
	if not _click_current_target(app, "craps_bet", dont_index): return
	for frame in range(2): await process_frame
	var ui := app._current_game_surface_ui_state()
	_check(ui.get("craps_pending_bets", {}) == {"dont_pass": 2} and bool(app.game_surface_canvas.state.get("can_roll", false)), "one actual $2 Don't Pass draft enables THROW")
	_check(_protected_paid(run) == original_protected, "uncommitted selection has no funding/debit/history/RNG effect")
	var throw_position: Vector2 = app.game_surface_canvas.local_position_for_surface_action("craps_throw")
	if not _click_current_target(app, "craps_throw"): return
	var result: Dictionary = app.last_game_result.duplicate(true)
	var table: Dictionary = app.current_game._table_state_preview(run, run.current_environment)
	if not _check(bool(result.get("ok", false)) and int(result.get("craps_total_wager", -1)) == 2 and int(table.get("roll_count", 0)) == 1, "enabled mouse THROW resolves exactly one existing two-dollar contract"):
		facts["failed_throw_message"] = str(result.get("message", "")); return
	_check(table.get("last_committed_bets", {}) == {"dont_pass": 2}, "only the staged Don't Pass contract is committed")
	_check(run.bankroll == 50 + int(result.get("bankroll_delta", 0)) and run.grand_casino_chips == 0, "actual cash change matches the authoritative natural settlement, with no invented payout")
	_check(run.story_log.size() == original.size() + 1 and run.story_log.slice(0, original.size()) == original, "exactly one new game result preserves all prior paid-trip history")
	_check(str(run.story_log.back().get("game_id", "")) == "craps" and int(run.story_log.back().get("stake", -1)) == 2, "one durable two-dollar result receipt")
	_check(app._current_game_surface_ui_state().get("craps_pending_bets", {}).is_empty(), "consumed draft is not retained for a second charge")
	_check(_non_craps_games(run.to_save_snapshot()) == before_other and _protected_paid(run).get("inventory") == original_protected.get("inventory") and run.debt.is_empty(), "other games, original Twine inventory and debt remain unchanged")
	var once := _protected_paid(run)
	# Same-frame duplicate input; do not wait out a roll or submit a new draft.
	_mouse_click_at(app, throw_position)
	var duplicate_unchanged := _protected_paid(run) == once
	_check(duplicate_unchanged, "same-frame duplicate THROW causes no second roll, funding, history or RNG change")
	facts["before_cold_protected"] = once
	facts["before_cold_table"] = run.current_environment.get("game_states", {}).get("craps", {}).duplicate(true)
	var before_cold_story := run.story_log.duplicate(true)
	app.save_foundation_run(); app.save_service.wait_for_async_save()
	_check(app.return_to_main_menu(), "normal private Save then Menu")
	app.save_service = SaveService.new()
	if _check(app.load_foundation_run(), "fresh-service Continue of exactly one natural throw"):
		app.set_process(false)
		facts["after_cold_protected"] = _protected_paid(app.run_state)
		facts["after_cold_table"] = app.run_state.current_environment.get("game_states", {}).get("craps", {}).duplicate(true)
		var cold_diffs: Array = []
		_semantic_diff(facts.before_cold_table, facts.after_cold_table, "table", cold_diffs)
		_semantic_diff(before_cold_story, app.run_state.story_log, "story", cold_diffs)
		facts["cold_semantic_differences"] = cold_diffs
		var financial_once := once.duplicate(); financial_once.erase("craps"); financial_once.erase("story_log")
		var financial_cold := _protected_paid(app.run_state); financial_cold.erase("craps"); financial_cold.erase("story_log")
		# JSON can change nested int/float representation. Compare every table
		# and story field recursively with exact numeric values, no tolerance;
		# wallet/RNG/debt/inventory retain their independent strict fingerprints.
		_check(cold_diffs.is_empty() and financial_cold == financial_once, "cold result, point/funding, wallet, full story and RNG preserve exact semantic values")
	facts["one_throw"] = {"wager": result.get("craps_total_wager"), "net_cash": result.get("bankroll_delta"), "roll_count": table.get("roll_count"), "point": table.get("point"), "same_frame_duplicate_unchanged": duplicate_unchanged, "cold_semantic_differences": facts.get("cold_semantic_differences", ["missing"])}

func _click_current_target(app: Host, action: String, index: int = -1) -> bool:
	var point: Vector2 = app.game_surface_canvas.local_position_for_surface_action(action, index)
	if point.x < 0.0 or point.y < 0.0:
		_check(false, "rendered mouse hit target exists: " + action)
		return false
	_mouse_click_at(app, point)
	return true

func _mouse_click_at(app: Host, point: Vector2) -> void:
	var press := InputEventMouseButton.new(); press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true; press.button_mask = MOUSE_BUTTON_MASK_LEFT; press.position = point
	app.game_surface_canvas._gui_input(press)
	var release := InputEventMouseButton.new(); release.button_index = MOUSE_BUTTON_LEFT; release.pressed = false; release.position = point
	app.game_surface_canvas._gui_input(release)

func _protected_paid(run: RunState) -> Dictionary:
	var result: Dictionary = {}
	var source := run.to_save_snapshot()
	for key in ["bankroll", "grand_casino_chips", "suspicion", "debt", "grand_casino_atm_debt", "inventory", "rng_seed", "rng_state", "story_log", "story_money_archive", "run_status"]:
		result[str(key)] = Fingerprint.canonical_fingerprint(source.get(key))
	result["craps"] = Fingerprint.canonical_fingerprint(run.current_environment.get("game_states", {}).get("craps", {}))
	return result

func _non_craps_games(value: Variant) -> String:
	var selected: Dictionary = {}; _collect_games(value, "", selected)
	return Fingerprint.canonical_fingerprint(selected)

func _semantic_diff(a: Variant, b: Variant, path: String, found: Array) -> void:
	if typeof(a) == TYPE_DICTIONARY and typeof(b) == TYPE_DICTIONARY:
		var keys: Array = a.keys()
		for key in b:
			if not keys.has(key): keys.append(key)
		for key in keys:
			if not a.has(key) or not b.has(key): found.append({"path": path + "/" + str(key), "missing": "before" if not a.has(key) else "after"})
			else: _semantic_diff(a[key], b[key], path + "/" + str(key), found)
	elif typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY and a.size() == b.size():
		for i in range(a.size()): _semantic_diff(a[i], b[i], path + "/" + str(i), found)
	elif a != b:
		found.append({"path": path, "a": a, "b": b, "a_type": typeof(a), "b_type": typeof(b), "a_precision": "%.17f" % float(a) if typeof(a) in [TYPE_INT, TYPE_FLOAT] else "", "b_precision": "%.17f" % float(b) if typeof(b) in [TYPE_INT, TYPE_FLOAT] else ""})

func _collect_games(value: Variant, path: String, selected: Dictionary) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		for key in value:
			if str(key) == "game_states" and typeof(value[key]) == TYPE_DICTIONARY:
				for game_id in value[key]:
					if str(game_id) != "craps": selected[path + "/game_states/" + str(game_id)] = value[key][game_id]
			else: _collect_games(value[key], path + "/" + str(key), selected)
	elif typeof(value) == TYPE_ARRAY:
		for i in range(value.size()): _collect_games(value[i], path + "/" + str(i), selected)
