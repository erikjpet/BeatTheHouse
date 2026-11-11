extends SceneTree

const Foundation := preload("res://scripts/ui/foundation_main.gd")
const Runtime := preload("res://scripts/core/game_ritual_runtime.gd")
const TASK_ID := "BTH061-BLACKJACK-NET-FEEDBACK-001"
const EXPECTATIONS_FILE := "blackjack-net-feedback-expectations.json"
const OUTCOMES := ["win", "loss", "push"]

# Synthetic NEW shoes and wallets are installed before normal host entry and
# authority creation. Deal, Stand, Back, Save and Continue use production APIs.
# This is a feedback regression, never a replay/edit of the player's campaign.
class ClockHost extends Foundation:
	var fixture := "win"
	var test_msec := 100000
	func _source_allows_action_triggered_events(_source: String) -> bool:
		# This synthetic practice fixture needs ordinary economy/persistence, so
		# dev_game_test_mode is disabled after entry. Exclude unrelated world
		# cadence from the outset; never dismiss a committed event or edit live
		# narrative/authority state to make Back available after an observer hand.
		return false
	func _environment_simulation_time_msec() -> int:
		return test_msec
	func _game_test_seed(game_id: String) -> String:
		return "BLACKJACK-NET-FEEDBACK-SYNTHETIC-%s-%s" % [fixture, game_id]
	func _game_test_bankroll() -> int:
		return 92
	func _game_test_stake_floor() -> int:
		return 5
	func _game_test_stake_ceiling() -> int:
		return 13
	func _game_test_archetype() -> Dictionary:
		for value in library.environment_archetypes:
			if str((value as Dictionary).get("id", "")) == "grand_casino":
				return (value as Dictionary).duplicate(true)
		return {}
	func _game_test_environment(game_id: String, game: GameModule) -> Dictionary:
		run_state.grand_casino_chips = 13
		var environment := super._game_test_environment(game_id, game)
		var states: Dictionary = environment.get("game_states", {})
		var table: Dictionary = states.get(game_id, {})
		var ranks: Array = {"win": [8, 4, 7, 10, 9], "loss": [8, 10, 7, 9], "push": [10, 10, 7, 7]}.get(fixture, [8, 4, 7, 10, 9])
		var shoe: Array = []
		for rank in ranks:
			shoe.append({"rank": rank, "suit": shoe.size() % 4, "deck": 0})
		while shoe.size() < 100:
			shoe.append({"rank": 2, "suit": shoe.size() % 4, "deck": 0})
		table["shoe"] = shoe
		table["shoe_cursor"] = 0
		table["shoe_remaining"] = shoe.size()
		table["cut_card_remaining"] = 4
		table["reshuffle_pending"] = false
		table["patrons"] = []
		table["side_bets"] = []
		table["counting_enabled"] = false
		table["table_minimum"] = 5
		table["table_maximum"] = 13
		table["rules"] = {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}
		environment["game_states"] = {game_id: table}
		return environment

var checks := 0
var failures: Array[String] = []
var observations: Array = []
var expectations: Dictionary = {}
var private_root := ""

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	private_root = OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT")
	if not private_root.is_absolute_path() or OS.get_environment("BTH_SAVE_DIR").is_empty():
		push_error("Blackjack net feedback check requires an explicit isolated persistence root and BTH_SAVE_DIR.")
		quit(2)
		return
	var cold := OS.get_cmdline_user_args().has("--continue-only")
	if cold:
		var stored: Variant = JSON.parse_string(FileAccess.get_file_as_string(private_root.path_join(EXPECTATIONS_FILE)))
		if not _check(typeof(stored) == TYPE_DICTIONARY and not (stored as Dictionary).is_empty(), "cold process has prior synthetic save expectations"):
			_finish(cold)
			return
		expectations = stored as Dictionary
		for name in ["win", "loss", "push", "legacy_round_net", "win_sitout"]:
			await _continue_case(name, true)
	elif OS.get_cmdline_user_args().has("--watch-only"):
		await _play_case("win")
		_write_json(EXPECTATIONS_FILE, expectations)
	else:
		for outcome in OUTCOMES:
			await _play_case(outcome)
		_write_json(EXPECTATIONS_FILE, expectations)
	_finish(cold)

func _new_host(fixture: String) -> ClockHost:
	var app := ClockHost.new()
	app.fixture = fixture
	app.continuous_environment_clock_enabled = false
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_process(false)
	return app

func _play_case(outcome: String) -> void:
	var app := await _new_host(outcome)
	var started := app.start_game_test_session("blackjack")
	if not _check(bool(started.get("ok", false)), outcome + " enters synthetic Grand Blackjack through normal host"):
		await _close(app)
		return
	app.dev_game_test_mode = false
	app.autosave_slot_id = _slot(outcome)
	app.game_surface_canvas.set_process(false)
	_check(app.run_state.bankroll == 92 and app.run_state.grand_casino_chips == 13 and app.run_state.is_grand_casino_environment(), outcome + " starts with cash92/chips13 in chip venue")
	app.set_selected_stake(5, true)
	app._on_game_surface_action("blackjack_deal", 0)
	var popup := app.current_event_choice_popup_snapshot()
	if str(popup.get("popup_type", "")) == "wager_confirmation" and bool(popup.get("visible", false)):
		app.confirm_pending_wager_action()
	await _quiet_frames(app)
	_check(app.run_state.bankroll == 92 and app.run_state.grand_casino_chips == 8, outcome + " Deal debits exactly five chips once")
	_sample(app, app.test_msec + 10000, false)
	app._on_game_surface_action("blackjack_stand", 0)
	await _quiet_frames(app)
	for _step in range(5):
		if app.current_game == null or not app.current_game.wager_activity_incomplete(app.run_state, app.run_state.current_environment, app._current_game_surface_ui_state()):
			break
		_sample(app, app.test_msec + 2000, true)
		await _quiet_frames(app)
	_sample(app, app.test_msec + 20000, false)
	await _quiet_frames(app)
	var expected := _net(outcome)
	var table := _table(app)
	var last_result: Dictionary = table.get("last_result", {})
	_check(app.run_state.bankroll == 92 and app.run_state.grand_casino_chips == 13 + expected and not app.run_state.is_terminal(), outcome + " settlement preserves exact cash/chip balances and continuing run")
	_check(int(last_result.get("round_net_delta", 999)) == expected and int(table.get("hands_played", 0)) == 1, outcome + " normal hand settles once with expected net")
	_check(int(last_result.get("dealer_total", 0)) == int({"win": 23, "loss": 19, "push": 17}[outcome]), outcome + " fixed shoe follows normal dealer result")
	_check(int(app.last_game_result.get("outcome_bankroll_delta", 999)) == expected, outcome + " live table feedback already reports round net")
	_observe(app, outcome, "settled_table")
	var settled := _protected(app)
	app.back_to_environment()
	await _quiet_frames(app)
	_check(app.current_game == null and app.current_screen == "ENVIRONMENT", outcome + " normal Back reaches floor")
	_assert_floor(app, outcome, "after_back", expected)
	_check(_same(_protected(app), settled), outcome + " Back and feedback leave money/RNG/shoe/results/history unchanged")
	if outcome == "win":
		_projection_controls(app)
	app.save_foundation_run()
	await _quiet_frames(app)
	if app.save_service.async_save_in_flight():
		app.save_service.wait_for_async_save()
	_check(bool(app.save_service.slot_status(app.autosave_slot_id).get("has_loadable", false)), outcome + " normal Save persists isolated completed hand")
	expectations[outcome] = {"net": expected, "protected": _protected(app)}
	_check(_same(_protected(app), settled), outcome + " Save cannot apply another monetary result or change RNG/history")
	if outcome == "win":
		_save_legacy(app)
		await _sitout_case(app)
	await _close(app)
	await _continue_case(outcome, false)
	if outcome == "win":
		await _continue_case("legacy_round_net", false)
		await _continue_case("win_sitout", false)

func _sitout_case(app: ClockHost) -> void:
	# Re-enter normally, place no wager, and let the production round timer and
	# automation consume an actual observer hand. Never manufacture an authority
	# row: this is the zero-result producer implicated by the reported old +0.
	if not _check(app.enter_game("blackjack"), "paid win normally re-enters same table before observing next hand"):
		return
	app.game_surface_canvas.set_process(false)
	var paid_hands := int(_table(app).get("hands_played", 0))
	var paid_money := {"cash": app.run_state.bankroll, "chips": app.run_state.grand_casino_chips}
	for _step in range(8):
		_sample(app, app.test_msec + 25000, true)
		await _quiet_frames(app)
		if int(_table(app).get("hands_played", 0)) > paid_hands:
			break
	var tail: Dictionary = app.run_state.story_log.back() if not app.run_state.story_log.is_empty() else {}
	_check(int(_table(app).get("hands_played", 0)) == paid_hands + 1 and bool(tail.get("sat_out", false)), "normal clock automation produces one genuine zero observer hand after paid win")
	_check(app.run_state.bankroll == int(paid_money.cash) and app.run_state.grand_casino_chips == int(paid_money.chips), "observer hand changes neither wallet")
	# Allow the queued production result refresh and the canvas's normal 250 ms
	# final-card handoff to publish before requesting Back. Do not clear guards,
	# popups, authority sessions or result ownership to manufacture an exit.
	await _quiet_frames(app)
	_sample(app, app.test_msec + 20000, false)
	await create_timer(0.30).timeout
	_sample(app, app.test_msec + 1, false)
	await _quiet_frames(app)
	var observed := _protected(app)
	_observe(app, "win_sitout", "automatic_observer_table")
	app.back_to_environment()
	await _quiet_frames(app)
	_check(app.current_game == null and app.current_screen == "ENVIRONMENT", "observer normal Back reaches floor after result handoff")
	_assert_floor(app, "win_sitout", "after_back", 5)
	_check(_same(_protected(app), observed), "observer feedback selection never edits actual zero history or accounting")
	app.autosave_slot_id = _slot("win_sitout")
	app.save_foundation_run()
	await _quiet_frames(app)
	if app.save_service.async_save_in_flight():
		app.save_service.wait_for_async_save()
	expectations["win_sitout"] = {"net": 5, "protected": _protected(app)}

func _projection_controls(app: ClockHost) -> void:
	# Detached, explicitly synthetic receipt projections supplement the host
	# fixture. They never resolve a wager, forge an authority ledger, or rewrite
	# any run story/accounting. Both selectors must obey the same contracts.
	var before := _protected(app)
	var previous := app.last_game_result
	var paid := _projection_row(5, 10, "chips")
	for reader_name in ["_result_from_story_log", "_game_result_from_story_log"]:
		var reader := Callable(app, reader_name)
		for control in [
			{"name": "surrender", "net": -5, "leg": 5, "currency": "chips", "legacy": false},
			{"name": "zero_push", "net": 0, "leg": 5, "currency": "chips", "legacy": false},
			{"name": "cash", "net": 5, "leg": 10, "currency": "cash", "legacy": false},
			{"name": "legacy_cash", "net": 5, "leg": 10, "currency": "cash", "legacy": true},
		]:
			var row := _projection_row(int(control.net), int(control.leg), str(control.currency))
			if bool(control.legacy):
				row.erase("outcome_bankroll_delta")
			var original := _json_hash(row)
			var restored: Dictionary = reader.call([row])
			app.last_game_result = restored
			var view: Dictionary = app._environment_result_feedback_view()
			var expected_label := "Blackjack net: %+d chips." % int(control.net) if str(control.currency) == "chips" else "Blackjack net: $%+d." % int(control.net)
			_check(str(view.get("text", "")).begins_with(expected_label), reader_name + "/" + str(control.name) + " explicitly distinguishes hand net from movement")
			_check(str(restored.get("currency", "")) == str(control.currency) and int(restored.get("currency_delta", 999)) == int(control.leg), reader_name + "/" + str(control.name) + " preserves recorded currency/return leg")
			_check(int(restored.get("outcome_bankroll_delta", 999)) == int(control.net) and _json_hash(row) == original, reader_name + "/" + str(control.name) + " restores net metadata without rewriting receipt")
			_projection_observation(app, reader_name + "_" + str(control.name), row, restored, view)
		for malformed in ["5", 2.5, true, null]:
			var row := _projection_row(5, 10, "chips")
			row["round_net_delta"] = malformed
			row["outcome_bankroll_delta"] = malformed
			var restored: Dictionary = reader.call([row])
			app.last_game_result = restored
			var view: Dictionary = app._environment_result_feedback_view()
			_check(not str(view.get("text", "")).contains("Blackjack net:"), reader_name + " rejects malformed/non-integral net field " + str(malformed))
			_check(int(restored.get("currency_delta", 999)) == 10, reader_name + " malformed net never changes actual credit")
		var unknown_source := _projection_row(5, 10, "chips")
		for key in ["currency", "currency_delta", "environment_id", "environment_archetype_id"]:
			unknown_source.erase(key)
		var unknown_units: Dictionary = reader.call([unknown_source])
		_check(not unknown_units.has("currency") and app._round_net_feedback_lead(unknown_units).is_empty(), reader_name + " unknown recorded source never invents cash/chip units for net")
		app.last_game_result = unknown_units
		var unknown_units_view: Dictionary = app._environment_result_feedback_view()
		_check(int(unknown_units_view.get("bankroll_delta", 999)) == 10 and not str(unknown_units_view.get("text", "")).contains("$+5"), reader_name + " unknown units retain original cash-alias fallback without substituting new net")
		var watch := _projection_row(0, 0, "chips")
		watch["sat_out"] = true
		watch["total_wager"] = 0
		watch["environment_id"] = "grand_casino_synthetic_observer"
		var selected: Dictionary = reader.call([paid, watch])
		_check(int(selected.get("outcome_bankroll_delta", 999)) == 5 and int(selected.get("currency_delta", 999)) == 10, reader_name + " ignores only a genuine zero/no-consequence observer suffix")
		for consequence in ["heat", "nonzero", "caught", "ended"]:
			var row := watch.duplicate(true)
			if consequence == "heat":
				row["suspicion_delta"] = 3
			elif consequence == "nonzero":
				row["currency_delta"] = 2
			elif consequence == "caught":
				row["dealer_caught_cheat"] = true
			else:
				row["ended"] = true
			var original := _json_hash(row)
			var restored: Dictionary = reader.call([paid, row])
			_check(str(restored.get("environment_id", "")) == str(row.environment_id) and _json_hash(row) == original, reader_name + " retains observer row with " + consequence + " consequence unchanged")
		var penalty := {"type": "game_action", "game_id": "blackjack", "action_id": "peek_hole_card", "environment_archetype_id": "grand_casino", "environment_id": "grand_casino_synthetic_penalty", "bankroll_delta": -40, "nominal_bankroll_delta": -40, "dealer_caught_cheat": true}
		var unknown: Dictionary = reader.call([penalty])
		app.last_game_result = unknown
		var unknown_view: Dictionary = app._environment_result_feedback_view()
		_check(bool(unknown.get("applied_currency_unknown", false)) and not unknown.has("currency_delta") and str(unknown_view.get("text", "")).contains("Chip loss unknown"), reader_name + " legacy caught penalty stays unmeasured")
		_check(not str(unknown_view.get("text", "")).contains("Blackjack net:"), reader_name + " unknown penalty never fabricates a round net")
		for applied_delta in [-10, 0]:
			var measured := penalty.duplicate(true)
			measured["applied_currency_settlement"] = {"schema": "bth.applied_currency_settlement/v1", "currency": "chips", "delta": applied_delta, "cash_delta": 0, "chips_delta": applied_delta, "nominal_cash_delta": 0, "nominal_chips_delta": -40}
			var restored: Dictionary = reader.call([measured])
			app.last_game_result = restored
			var view: Dictionary = app._environment_result_feedback_view()
			_check(not bool(restored.get("applied_currency_unknown", false)) and int(restored.get("currency_delta", 999)) == applied_delta and str(view.get("text", "")).contains("Chip change: %+d chips." % applied_delta), reader_name + " measured penalty preserves exact applied loss including zero")
	app.last_game_result = previous
	_check(_same(_protected(app), before), "all detached projection controls preserve actual wallets/RNG/shoe/results/full journal")

func _projection_row(net: int, leg: int, currency: String) -> Dictionary:
	return {"type": "game_action", "game_id": "blackjack", "action_id": "play_basic", "bankroll_delta": leg, "currency": currency, "currency_delta": leg, "round_net_delta": net, "outcome_bankroll_delta": net, "suspicion_delta": 0, "sat_out": false, "stake": maxi(0, leg - net), "total_wager": maxi(0, leg - net), "environment_id": "grand_casino_synthetic_paid", "environment_archetype_id": "grand_casino", "message": "Synthetic receipt projection."}

func _projection_observation(app: ClockHost, name: String, row: Dictionary, restored: Dictionary, view: Dictionary) -> void:
	observations.append({"fixture": "synthetic_projection_" + name, "boundary": "detached_reader_control", "screen": app.current_screen, "cash": app.run_state.bankroll, "chips": app.run_state.grand_casino_chips, "raw_input_row": row.duplicate(true), "raw_restored_result": restored.duplicate(true), "floor_view": view.duplicate(true), "protected": _protected(app)})

func _save_legacy(app: ClockHost) -> void:
	var legacy := RunState.new()
	legacy.from_dict(app.run_state.to_dict())
	var changed := 0
	for value in legacy.story_log:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = value
		if str(row.get("type", "")) == "game_action" and str(row.get("game_id", "")) == "blackjack" and row.has("round_net_delta"):
			row.erase("outcome_bankroll_delta")
			row.erase("blackjack_round_net_delta")
			changed += 1
	_check(changed == 1, "legacy synthetic clone retains one historical round_net_delta without newer outcome alias")
	_check(app.save_service.save_run(legacy, _slot("legacy_round_net")) == OK, "legacy synthetic clone saved through official codec")
	var live := app.run_state
	app.run_state = legacy
	expectations["legacy_round_net"] = {"net": 5, "protected": _protected(app)}
	app.run_state = live

func _continue_case(name: String, cold: bool) -> void:
	if not _check(expectations.has(name), name + " has completed synthetic expectation"):
		return
	var app := await _new_host("continue_" + name)
	app.autosave_slot_id = _slot(name)
	if _check(app.load_foundation_run(), name + " normal Continue loads isolated save"):
		await _quiet_frames(app)
		_check(app.current_game == null and app.current_screen == "ENVIRONMENT", name + " Continue restores floor")
		_assert_floor(app, name, "cold_continue" if cold else "new_host_continue", int(expectations[name].net))
		_check(_same(_protected(app), expectations[name].protected), name + " Continue and feedback preserve money/RNG/shoe/results/history and settlement count")
	await _close(app)

func _assert_floor(app: ClockHost, name: String, boundary: String, expected: int) -> void:
	var before := _protected(app)
	var view: Dictionary = app._environment_result_feedback_view()
	var text_value := str(view.get("text", ""))
	_check(bool(view.get("visible", false)) and text_value.begins_with("Blackjack net: %+d chips." % expected), "%s/%s floor first line explicitly shows net %+d chips" % [name, boundary, expected])
	_check(app.environment_result_body_label != null and app.environment_result_body_label.is_visible_in_tree() and app.environment_result_body_label.text == text_value, name + "/" + boundary + " production floor Label publishes the same visible result")
	_check(not text_value.contains("$"), name + "/" + boundary + " floor keeps chip denomination")
	var result: Dictionary = view.get("result", {})
	_check(int(result.get("currency_delta", 999)) == expected + 5, name + "/" + boundary + " original currency return leg remains unchanged")
	_check(int(result.get("outcome_bankroll_delta", 999)) == expected, name + "/" + boundary + " preserved outcome metadata uses round net")
	_observe(app, name, boundary)
	_check(_same(_protected(app), before), name + "/" + boundary + " repeated projection is read-only")

func _observe(app: ClockHost, name: String, boundary: String) -> void:
	var tail: Array = app.run_state.story_log.slice(maxi(0, app.run_state.story_log.size() - 4))
	observations.append({"fixture": "synthetic_" + name, "boundary": boundary, "screen": app.current_screen, "cash": app.run_state.bankroll, "chips": app.run_state.grand_casino_chips, "raw_last_game_result": app.last_game_result.duplicate(true), "raw_tail_story": tail.duplicate(true), "raw_table_last_result": (_table(app).get("last_result", {}) as Dictionary).duplicate(true), "floor_view": app._environment_result_feedback_view(), "published_floor_label": app.environment_result_body_label.text if app.environment_result_body_label != null else "", "host_message": app.message_label.text if app.message_label != null else "", "popup": app.current_event_choice_popup_snapshot(), "pending_all_in": app.pending_all_in_result_terminal_check, "terminal_presentation": app.terminal_game_result_presentation.duplicate(true), "protected": _protected(app)})

func _protected(app: ClockHost) -> Dictionary:
	var table := _table(app)
	var actions := 0
	var settlements := 0
	for value in app.run_state.story_log:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = value
		if str(row.get("type", "")) == "game_action" and str(row.get("game_id", "")) == "blackjack":
			actions += 1
			if row.has("round_net_delta"):
				settlements += 1
	return {"cash": app.run_state.bankroll, "chips": app.run_state.grand_casino_chips, "rng": app.run_state.rng_state, "clock": app.run_state.game_clock_minutes, "hands": int(table.get("hands_played", 0)), "shoe_sha256": _json_hash(table.get("shoe", [])), "result_sha256": _json_hash(table.get("last_result", {})), "history_sha256": _json_hash(app.run_state.story_log), "history_count": app.run_state.story_log.size(), "blackjack_actions": actions, "blackjack_settlements": settlements}

func _table(app: ClockHost) -> Dictionary:
	var states: Dictionary = app.run_state.current_environment.get("game_states", {})
	return states.get("blackjack", {})

func _sample(app: ClockHost, msec: int, automation: bool) -> void:
	app.test_msec = msec
	if app.current_game == null:
		return
	app.game_surface_canvas.apply_surface_state_patch({"surface_time_msec": msec, "surface_presentation_time_msec": msec})
	if automation:
		app._advance_game_surface_automation()
	app.last_game_surface_realtime_refresh_msec = 0
	app._advance_game_surface_realtime_state()
	app._advance_presented_bankroll()
	app.game_surface_canvas.set_process(false)

func _quiet_frames(app: ClockHost) -> void:
	for _index in range(4):
		await process_frame
		if app.game_surface_canvas != null:
			app.game_surface_canvas.set_process(false)

func _close(app: ClockHost) -> void:
	if app.save_service.async_save_in_flight():
		app.save_service.wait_for_async_save()
	app.queue_free()
	await process_frame

func _slot(name: String) -> String:
	return "blackjack_net_feedback_" + name

func _net(outcome: String) -> int:
	return int({"win": 5, "loss": -5, "push": 0}[outcome])

func _json_hash(value: Variant) -> String:
	return Runtime.canonical_json(JSON.parse_string(JSON.stringify(value))).sha256_text()

func _same(left: Variant, right: Variant) -> bool:
	return _json_hash(left) == _json_hash(right)

func _write_json(name: String, value: Variant) -> void:
	var file := FileAccess.open(private_root.path_join(name), FileAccess.WRITE)
	if _check(file != null, "write isolated evidence " + name):
		file.store_string(JSON.stringify(value, "\t"))

func _finish(cold: bool) -> void:
	_write_json("blackjack-net-feedback-%s-observations.json" % ("cold" if cold else "host"), {"task_id": TASK_ID, "synthetic": true, "observations": observations})
	var summaries: Array = []
	for observation in observations:
		summaries.append({"fixture": observation.fixture, "boundary": observation.boundary, "cash": observation.cash, "chips": observation.chips, "floor_text": observation.floor_view.get("text", ""), "floor_delta": observation.floor_view.get("bankroll_delta", 0), "currency": observation.floor_view.get("result", {}).get("currency", "")})
	print("BLACKJACK_NET_FEEDBACK_RESULT " + JSON.stringify({"task_id": TASK_ID, "synthetic": true, "cold": cold, "checks": checks, "summaries": summaries, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
	return condition
