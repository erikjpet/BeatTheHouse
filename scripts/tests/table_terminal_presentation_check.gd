extends SceneTree

const Foundation := preload("res://scripts/ui/foundation_main.gd")
const Canvas := preload("res://scripts/ui/game_surface_canvas.gd")
const Runtime := preload("res://scripts/core/game_ritual_runtime.gd")

# Synthetic fixed shoes are installed before the normal host enters a disposable
# practice room. All wagers, card decisions, settlements and Save/Continue use
# production host APIs; only the presentation clock is controlled.
class ClockHost extends Foundation:
	var test_msec := 100000
	var fixture := "stand"
	var budget := 10
	func _environment_simulation_time_msec() -> int:
		return test_msec
	func _game_test_seed(game_id: String) -> String:
		return "TABLE-TERMINAL-%s-%s" % [fixture, game_id]
	func _game_test_bankroll() -> int:
		return budget
	func _game_test_stake_floor() -> int:
		return 20 if fixture == "baccarat" else 10
	func _game_test_stake_ceiling() -> int:
		return budget
	func _game_test_archetype() -> Dictionary:
		for value in library.environment_archetypes:
			if str((value as Dictionary).get("id", "")) == "bar":
				return (value as Dictionary).duplicate(true)
		return super._game_test_archetype()
	func _game_test_environment(game_id: String, game: GameModule) -> Dictionary:
		var environment := super._game_test_environment(game_id, game)
		var table := game.generate_environment_state(run_state, environment, run_state.create_rng("terminal_fixture"))
		if game_id in ["blackjack", "baccarat"]:
			var ranks: Array = [10, 10, 6, 9, 5, 8, 4, 3]
			if fixture == "hit": ranks = [10, 10, 6, 6, 10, 5, 4, 3]
			if game_id == "baccarat": ranks = [4, 2, 5, 3]
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
			table["table_minimum"] = 20 if game_id == "baccarat" else 10
			table["table_maximum"] = budget
			table["rules"] = {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true} if game_id == "blackjack" else table.get("rules", {})
		environment["game_states"] = {game_id: table}
		return environment

var failures: Array[String] = []
var checks := 0
var rows: Array = []
var boundaries: Array = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").is_empty():
		push_error("Table terminal presentation check requires isolated BTH_DISTRIBUTION_DATA_ROOT.")
		quit(2)
		return
	_check_finite_canvas_channels()
	for fixture in ["stand", "hit", "nonending", "reduced"]:
		await _blackjack(fixture)
	await _baccarat()
	await _machine_terminal_boundary()
	print("TABLE_TERMINAL_PRESENTATION_RESULT " + JSON.stringify({"checks": checks, "rows": rows, "boundaries": boundaries, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _new_host(fixture: String, budget: int) -> ClockHost:
	var app := ClockHost.new()
	app.fixture = fixture
	app.budget = budget
	app.continuous_environment_clock_enabled = false
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_process(false)
	# Exercise the actual live accessibility setting; Foundation's internal
	# projection helpers read the UserSettings resource as well as its wrapper.
	app.user_settings.reduce_motion = fixture == "reduced"
	return app

func _start(app: ClockHost, game_id: String) -> bool:
	var start := app.start_game_test_session(game_id)
	_check(bool(start.get("ok", false)), "%s normal host entry" % app.fixture)
	if not bool(start.get("ok", false)): return false
	# The launcher supplies isolated authored room structure; use the ordinary
	# run/economy/persistence behavior for the action being tested.
	app.dev_game_test_mode = false
	app.autosave_slot_id = "table_terminal_%s" % app.fixture
	app.game_surface_canvas.set_process(false)
	return true

func _blackjack(fixture: String) -> void:
	var nonending := fixture == "nonending"
	var app := await _new_host(fixture, 100 if nonending else 10)
	if not _start(app, "blackjack"):
		app.queue_free()
		return
	app.set_selected_stake(10, true)
	app._on_game_surface_action("blackjack_deal", 0)
	_confirm_wager_if_open(app)
	await _quiet_frames(app)
	_boundary(app, "opening_wager", "blackjack")
	_check(app.run_state.bankroll == (90 if nonending else 0) and not app.run_state.is_terminal(), "%s opening wager debits once and leaves live hand" % fixture)
	_sample(app, app.test_msec + 10000, false)
	app._on_game_surface_action("blackjack_hit" if fixture == "hit" else "blackjack_stand", 0)
	await _quiet_frames(app)
	# A bust card must finish moving before the automatic settlement command.
	for step in range(5):
		if app.run_state.is_terminal() or app.current_game == null or not app.current_game.wager_activity_incomplete(app.run_state, app.run_state.current_environment, app._current_game_surface_ui_state()): break
		_sample(app, app.test_msec + 2000, true)
		await _quiet_frames(app)
	var table := _table(app, "blackjack")
	var settled: Dictionary = table.get("last_result", {})
	_boundary(app, "settled", "blackjack")
	_check(int(table.get("hands_played", 0)) == 1 and not (settled.get("dealer_cards", []) as Array).is_empty(), "%s final dealer hand settled exactly once" % fixture)
	var hand_results: Array = settled.get("hand_results", [])
	if fixture == "hit":
		_check(not hand_results.is_empty() and str((hand_results[0] as Dictionary).get("outcome", "")) == "bust", "Hit fixture visibly resolves a player bust")
	if nonending:
		_sample(app, app.test_msec + 12000, true)
		_check(not app.run_state.is_terminal() and app.current_screen == "GAME" and app.run_state.bankroll == 90, "Ordinary loss keeps the active run/table")
		rows.append({"fixture": fixture, "cash": app.run_state.bankroll, "screen": app.current_screen, "hands": table.get("hands_played", 0)})
	else:
		await _terminal_wait(app, "blackjack", fixture == "stand")
	await _close(app)

func _baccarat() -> void:
	var app := await _new_host("baccarat", 20)
	if not _start(app, "baccarat"):
		app.queue_free()
		return
	var denoms: Array = app.game_surface_canvas.state.get("chip_denominations", [])
	var chip_index := denoms.find(20)
	_check(chip_index >= 0, "Baccarat exposes the all-in twenty chip")
	app._on_game_surface_action("baccarat_chip", chip_index)
	var targets: Array = app.game_surface_canvas.state.get("bet_targets", [])
	var banker := -1
	for index in range(targets.size()):
		var target: Dictionary = targets[index]
		if str(target.get("id", target.get("bet_id", ""))) == "banker": banker = index
	_check(banker >= 0, "Baccarat exposes its normal Banker wager")
	if banker < 0:
		await _close(app)
		return
	app._on_game_surface_action("baccarat_bet", banker)
	_boundary(app, "bets_placed", "baccarat")
	_check(int((app.game_surface_canvas.state.get("baccarat_bets", {}) as Dictionary).get("banker", 0)) == 20, "Baccarat Banker wager risks the full twenty cash")
	app._on_game_surface_action("baccarat_deal", 0)
	app._on_game_surface_action("baccarat_deal", 0)
	_confirm_wager_if_open(app)
	await _quiet_frames(app)
	_boundary(app, "settled", "baccarat")
	await _terminal_wait(app, "baccarat", false)
	await _close(app)

func _machine_terminal_boundary() -> void:
	var app := await _new_host("slot_legacy_boundary", 10)
	if not _start(app, "slot"):
		await _close(app)
		return
	# Synthetic host-boundary fixture: no wager/outcome is manufactured. This
	# checks that the table-only fix preserves the established machine all-in
	# acknowledgement and explicit force/Back routing contract.
	app.run_state.bankroll = 0
	app.pending_all_in_result_terminal_check = true
	app.last_game_result = {"ok": true}
	var rng := app.run_state.rng_state
	var result := app._evaluate_run_terminal_state()
	_check(not app.run_state.is_terminal() and bool(result.get("bankroll_zero_deferred", false)), "Machine all-in result retains its existing deferred terminal contract")
	_check(app.current_screen == "GAME" and app.terminal_game_result_presentation.is_empty(), "Table presentation wait does not take ownership of a machine result")
	app._evaluate_run_terminal_state(true)
	_check(app.run_state.is_terminal() and app.current_screen == "FAILURE" and app.current_game == null, "Explicit machine acknowledgement keeps its existing immediate report route")
	_check(app.run_state.rng_state == rng, "Machine terminal boundary does not advance RNG")
	await _close(app)


func _terminal_wait(app: ClockHost, game_id: String, check_save: bool) -> void:
	var run := app.run_state
	_check(run.is_terminal() and run.run_failure_reason == RunState.FAILURE_BANKROLL_ZERO, "%s losing settlement classifies the run immediately" % app.fixture)
	_check(app.current_screen == "GAME" and app.current_game != null, "%s keeps the final table visible after settlement" % app.fixture)
	if app.current_game == null: return
	var before := _financial_signature(app, game_id)
	app._on_game_surface_action("surface_legal", 0)
	app._advance_game_surface_automation()
	_check(_financial_signature(app, game_id) == before, "%s input and automation cannot begin another settlement during the terminal result" % app.fixture)
	app.back_to_environment()
	_check(app.current_screen == "GAME" and app.current_game != null, "%s Back cannot cut off the pending final result" % app.fixture)
	var initial := app.test_msec
	_sample(app, initial, false)
	app.call("_advance_terminal_game_result_presentation")
	_boundary(app, "initial_result_wait", game_id)
	_check(app.current_screen == "GAME", "%s waits through its result animation" % app.fixture)
	# UI refresh and save preparation must not bypass the same wait contract.
	app._refresh()
	_check(app.current_screen == "GAME", "%s broad refresh preserves the final hand" % app.fixture)
	if check_save:
		_check(app._autosave_foundation_run("Interrupted result saved.", true), "Save during terminal presentation succeeds")
		_check(app.current_screen == "GAME", "Save preparation preserves the final hand")
		var resumed := await _new_host("resume", 10)
		resumed.autosave_slot_id = app.autosave_slot_id
		_check(resumed.load_foundation_run(), "Continue loads the interrupted terminal save")
		_check(resumed.current_screen == "FAILURE" and _financial_signature(resumed, game_id) == before, "Continue routes the already-settled ending without replaying money, RNG, shoe or outcome")
		await _close(resumed, false)
	# One finite jump completes even the longest authored result channels. The
	# canvas's real-time 250 ms handoff still receives a bounded real frame wait.
	if app.fixture != "reduced":
		_sample(app, initial + 15000, false)
		await create_timer(0.30).timeout
		app.game_surface_canvas.set_process(false)
		app.call("_advance_terminal_game_result_presentation")
		_boundary(app, "animations_completed", game_id)
	else:
		_check(app.game_surface_canvas.reduce_motion and not app.game_surface_canvas.surface_finite_result_presentation_active(), "Reduced motion skips transitions while preserving result readability")
	_check(app.current_screen == "GAME", "%s readable final result precedes run report" % app.fixture)
	_sample(app, app.test_msec + 1199, false)
	app.call("_advance_terminal_game_result_presentation")
	_boundary(app, "readability_1199", game_id)
	_check(app.current_screen == "GAME", "%s retains result for the full readability interval" % app.fixture)
	_sample(app, app.test_msec + 2, false)
	app.call("_advance_terminal_game_result_presentation")
	_boundary(app, "after_readability", game_id)
	_check(app.current_screen == "FAILURE" and app.current_game == null, "%s automatically advances to the correct failed-run screen" % app.fixture)
	_check(_financial_signature(app, game_id) == before, "%s presentation/routing do not settle twice or change accounting" % app.fixture)
	rows.append({"fixture": app.fixture, "cash": run.bankroll, "screen": app.current_screen, "reason": run.run_failure_reason, "signature": before})

func _sample(app: ClockHost, msec: int, automation: bool) -> void:
	app.test_msec = msec
	if app.current_game == null: return
	app.game_surface_canvas.apply_surface_state_patch({"surface_time_msec": msec, "surface_presentation_time_msec": msec})
	if automation: app._advance_game_surface_automation()
	app.last_game_surface_realtime_refresh_msec = 0
	app._advance_game_surface_realtime_state()
	app._advance_presented_bankroll()
	app.game_surface_canvas.set_process(false)

func _quiet_frames(app: ClockHost) -> void:
	for _index in range(4):
		await process_frame
		if app.game_surface_canvas != null: app.game_surface_canvas.set_process(false)

func _confirm_wager_if_open(app: ClockHost) -> void:
	var popup := app.current_event_choice_popup_snapshot()
	if str(popup.get("popup_type", "")) == "wager_confirmation" and bool(popup.get("visible", false)):
		app.confirm_pending_wager_action()

func _table(app: ClockHost, game_id: String) -> Dictionary:
	var states: Dictionary = app.run_state.current_environment.get("game_states", {})
	return states.get(game_id, {})

func _financial_signature(app: ClockHost, game_id: String) -> Dictionary:
	var table := _table(app, game_id)
	# Compare both saves in JSON's number domain (loaded JSON numbers are floats).
	var shoe_json := Runtime.canonical_json(JSON.parse_string(JSON.stringify(table.get("shoe", []))))
	var result_json := Runtime.canonical_json(JSON.parse_string(JSON.stringify(table.get("last_result", {}))))
	return {"cash": app.run_state.bankroll, "chips": app.run_state.grand_casino_chips, "rng": app.run_state.rng_state, "clock": app.run_state.game_clock_minutes, "hands": int(table.get("hands_played", 0)), "shoe_sha256": shoe_json.sha256_text(), "result_sha256": result_json.sha256_text()}

func _boundary(app: ClockHost, label: String, game_id: String) -> void:
	var table := _table(app, game_id)
	var ledger: Dictionary = table.get("_blackjack_action_authority", {})
	var session: Dictionary = ledger.get("session", {})
	var surface: Dictionary = app.game_surface_canvas.state
	var channels: Array = []
	for channel_value in surface.get("surface_animation_channels", []):
		var channel: Dictionary = channel_value
		channels.append({"id": channel.get("id", ""), "active": app.game_surface_canvas.surface_animation_active(str(channel.get("id", ""))), "duration": channel.get("duration_msec", 0), "started": channel.get("started_msec", 0), "clock": channel.get("clock_source", ""), "elapsed": app.game_surface_canvas.surface_elapsed(str(channel.get("id", "")))})
	var facts := {"fixture": app.fixture, "boundary": label, "screen": app.current_screen, "cash": app.run_state.bankroll, "terminal": app.run_state.is_terminal(), "action": app.last_game_result.get("action_id", ""), "ok": app.last_game_result.get("ok", false), "message": str(app.message_label.text).left(180), "hands": table.get("hands_played", 0), "phase": session.get("phase", session.get("round_phase", "")), "ui_phase": surface.get("phase", ""), "session_keys": session.keys(), "money_pending": surface.get("money_presentation_pending", false), "reduce_motion": app.game_surface_canvas.reduce_motion, "setting_reduce_motion": app.user_settings.reduce_motion, "finite_active": app.game_surface_canvas.surface_finite_result_presentation_active(), "ready_msec": app.terminal_game_result_ready_msec, "host_msec": app.test_msec, "surface_msec": surface.get("surface_time_msec", 0), "presentation_msec": surface.get("surface_presentation_time_msec", 0), "resolved_at_msec": (table.get("last_result", {}) as Dictionary).get("resolved_at_msec", 0), "paused": app._simulation_progression_paused(), "pause_owners": app.application_pause_owners.keys(), "realtime_enabled": app.game_surface_canvas.surface_realtime_state_refresh_enabled(), "channels": channels}
	boundaries.append(facts)

func _check_finite_canvas_channels() -> void:
	var canvas := Canvas.new()
	root.add_child(canvas)
	canvas.render_game_snapshot({"game_id": "finite_fixture", "surface_time_msec": 100000, "surface_animation_channels": [GameModule.surface_animation_channel("challenge", "waiting", 0, 100000, {"clock_source": "surface"})]})
	canvas.set_process(false)
	_check(canvas.surface_transition_animation_active(), "Zero-duration interactive challenge remains active for ordinary surface consumers")
	_check(not canvas.surface_finite_result_presentation_active(), "Zero-duration interactive challenge cannot hold a terminal result forever")
	canvas.apply_surface_state_patch({"surface_animation_channels": [GameModule.surface_animation_channel("challenge", "waiting", 0, 100000, {"clock_source": "surface"}), GameModule.surface_animation_channel("result", "dealing", 1000, 100000, {"clock_source": "surface"})]})
	canvas.set_process(false)
	_check(canvas.surface_finite_result_presentation_active(), "Finite result animation holds terminal routing")
	canvas.apply_surface_state_patch({"surface_time_msec": 101001})
	canvas.set_process(false)
	_check(not canvas.surface_finite_result_presentation_active(), "Finished finite result releases even while interactive challenge remains active")
	canvas.apply_surface_state_patch({"surface_time_msec": 100000, "reduce_motion": true})
	canvas.set_process(false)
	_check(not canvas.surface_finite_result_presentation_active(), "Reduced motion bypasses finite result transitions")
	canvas.free()

func _close(app: ClockHost, clear_save: bool = true) -> void:
	if app.save_service.async_save_in_flight(): app.save_service.wait_for_async_save()
	if clear_save: app.save_service.clear_run(app.autosave_slot_id)
	app.queue_free()
	await process_frame

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
