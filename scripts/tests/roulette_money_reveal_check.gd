extends SceneTree

const Foundation := preload("res://scripts/ui/foundation_main.gd")

# Real host actions/authority and real Save/Continue, with only the presentation
# clock controlled to sample both sides of each animation boundary without sleeps.
class ClockHost extends Foundation:
	var test_msec := 100000
	var cash_fixture := false
	func _environment_simulation_time_msec() -> int:
		return test_msec
	func _game_test_archetype() -> Dictionary:
		if cash_fixture:
			for value in library.environment_archetypes:
				if str((value as Dictionary).get("id", "")) == "bar":
					return (value as Dictionary).duplicate(true)
		return super._game_test_archetype()

class QuietAudio extends Node:
	var signs: Array = []
	func play_money_feedback(amount: int) -> bool:
		signs.append(amount)
		return true

var failures: Array[String] = []
var checks := 0
var rows: Array = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var app := ClockHost.new()
	app.cash_fixture = OS.get_cmdline_user_args().has("--cash")
	app.continuous_environment_clock_enabled = false
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_process(false)
	if OS.get_cmdline_user_args().has("--continue-only"):
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://roulette_money_reveal_expected.json"))
		app.autosave_slot_id = "roulette-money-reveal"
		_check(app.load_foundation_run(), "Cold Continue must load the isolated saved roulette run.")
		_check(app.run_state.bankroll == int(expected.cash) and app.run_state.grand_casino_chips == int(expected.chips) and app.run_state.rng_state == int(expected.rng), "Cold Continue must preserve money/RNG exactly.")
		_check(not app.presented_bankroll_hold_active and app._presented_bankroll() == app.run_state.bankroll, "Cold Continue must show actual cash without historical feedback.")
		_check(app.enter_game("roulette"), "Cold Continue must reopen roulette.")
		_sample(app, app.test_msec)
		_check(not bool(app.game_surface_canvas.state.get("money_presentation_pending", true)) and int(app.game_surface_canvas.state.get("bankroll", -1)) == app.run_state.wager_capacity_for_game("roulette", app.run_state.current_environment), "Cold re-entry must show the settled wallet and result without replaying an old process clock.")
		_finish(app)
		return
	var start: Dictionary = app.start_game_test_session("roulette")
	_check(bool(start.get("ok", false)), "Practice roulette must enter through the normal host.")
	if not bool(start.get("ok", false)):
		_finish(app)
		return
	var audio := QuietAudio.new()
	if app.environment_sfx_player != null:
		app.environment_sfx_player.queue_free()
	app.environment_sfx_player = audio
	app.add_child(audio)
	var seen_win := false
	var seen_loss := false
	for round_index in range(12):
		app.test_msec += 12000
		_sample(app, app.test_msec)
		app.structured_hud.reset_wallet_delta()
		var before := app.run_state.wager_capacity_for_game("roulette", app.run_state.current_environment)
		var target := _red_target(app)
		app._on_game_surface_action("roulette_bet", target)
		app._on_game_surface_action("roulette_spin", 0)
		app._on_game_surface_action("roulette_spin", 0)
		var result: Dictionary = app.last_game_result.duplicate(true)
		_check(bool(result.get("ok", false)) and str(result.get("action_id", "")) == "spin_roulette", "Normal two-click roulette spin must settle.")
		if not bool(result.get("ok", false)):
			break
		var delta := int((result.get("settlement", {}) as Dictionary).get("delta", result.get("bankroll_delta", 0)))
		var stake := int(result.get("roulette_total_wager", 0))
		seen_win = seen_win or delta > 0
		seen_loss = seen_loss or delta < 0
		var table: Dictionary = app.current_game.call("_table_state_preview", app.run_state, app.run_state.current_environment)
		var resolved := int((table.get("last_result", {}) as Dictionary).get("resolved_at_msec", 0))
		var rng := app.run_state.rng_state
		var settled := app.run_state.wager_capacity_for_game("roulette", app.run_state.current_environment)
		var presentations := int(app.structured_hud.current_snapshot().wallet_delta_presentations)
		var sounds := audio.signs.size()
		_check(settled == before + delta, "Authority must settle money immediately exactly once.")
		for elapsed in [0, 100, 4499, 5599, 5600, 7399, 8999]:
			_sample(app, resolved + elapsed)
			if elapsed == 100:
				app._on_game_surface_action("roulette_spin", 0)
				app._on_game_surface_action("roulette_spin", 0)
			_check(app._presented_game_funds() == before - stake, "Wallet must show only the stake debit before result reveal (%d)." % elapsed)
			_check(int(app.game_surface_canvas.state.get("bankroll", -1)) == before - stake, "Financial HUD refresh must not overwrite the masked roulette wallet (%d)." % elapsed)
			_check(app._current_game_result_snapshot().is_empty(), "Generic result copy must stay hidden before reveal.")
			_check(int(app.structured_hud.current_snapshot().wallet_delta_presentations) == presentations and audio.signs.size() == sounds, "Net badge/sound must not spoil the result.")
			_check(not bool(app._music_win_momentum_snapshot().get("big_win", false)), "Adaptive music must not expose a pending win.")
			_check(app._economy_cue_text() == "Stake on table", "Economy trend copy must not reveal the accepted outcome early.")
			_check(app.run_state.wager_capacity_for_game("roulette", app.run_state.current_environment) == settled and app.run_state.rng_state == rng, "Presentation must not resettle money or advance RNG.")
		_sample(app, resolved + 9000)
		_check(not app.presented_bankroll_hold_active and app._presented_game_funds() == settled, "Wallet must reveal the accepted balance at result presentation.")
		_check(not app._current_game_result_snapshot().is_empty(), "Result text must reveal with the wallet.")
		_check(int(app.structured_hud.current_snapshot().wallet_delta_presentations) == presentations + (1 if delta != 0 else 0), "Outcome feedback must present once.")
		_check(audio.signs.size() == sounds + (1 if delta != 0 else 0), "Outcome feedback sound must emit once.")
		_sample(app, resolved + 9100)
		_check(app.run_state.wager_capacity_for_game("roulette", app.run_state.current_environment) == settled and app.run_state.rng_state == rng and audio.signs.size() == sounds + (1 if delta != 0 else 0), "Repeated presentation frames must not duplicate settlement or audio.")
		rows.append({"round": round_index, "number": result.get("roulette_winning_number"), "stake": stake, "net": delta, "before": before, "after": settled})
		if seen_win and seen_loss and round_index >= 2:
			break
	_check(seen_win and seen_loss, "Bounded deterministic repeated spins must cover win and loss.")
	# Interrupt an accepted spin using real host Continue. Durable money and RNG
	# are already final; transient presentation must neither replay nor survive it.
	app.test_msec += 12000
	_sample(app, app.test_msec)
	app._on_game_surface_action("roulette_bet", _red_target(app))
	app._on_game_surface_action("roulette_spin", 0)
	app._on_game_surface_action("roulette_spin", 0)
	var final_cash := app.run_state.bankroll
	var final_chips := app.run_state.grand_casino_chips
	var final_rng := app.run_state.rng_state
	app.autosave_slot_id = "roulette-money-reveal"
	var save_error := app.save_service.save_run(app.run_state, app.autosave_slot_id)
	_check(save_error == OK, "Mid-spin Save must persist the committed authority state.")
	var expected_file := FileAccess.open("user://roulette_money_reveal_expected.json", FileAccess.WRITE)
	expected_file.store_string(JSON.stringify({"cash": final_cash, "chips": final_chips, "rng": str(final_rng)}))
	expected_file.close()
	_check(app.load_foundation_run(), "Continue must accept the saved roulette state.")
	_check(app.run_state.bankroll == final_cash and app.run_state.grand_casino_chips == final_chips and app.run_state.rng_state == final_rng, "Save/Continue must not duplicate or lose payout/RNG.")
	_check(not app.presented_bankroll_hold_active and app._presented_bankroll() == final_cash, "Continue must discard transient wallet masking.")
	app._flush_money_feedback()
	_check(app.money_feedback_pending.is_empty(), "Continue must not replay a historical monetary event.")
	_check(app.enter_game("roulette"), "Roulette must re-enter after Continue.")
	_sample(app, app.test_msec)
	_check(not bool(app.game_surface_canvas.state.get("money_presentation_pending", true)), "Continue re-entry must not replay or mask a settled spin.")
	app.test_msec += 12000
	_sample(app, app.test_msec)
	app._on_game_surface_action("roulette_bet", _red_target(app))
	app._on_game_surface_action("roulette_spin", 0)
	app._on_game_surface_action("roulette_spin", 0)
	final_cash = app.run_state.bankroll
	final_chips = app.run_state.grand_casino_chips
	final_rng = app.run_state.rng_state
	app.back_to_environment()
	_check(not app.presented_bankroll_hold_active and app._presented_bankroll() == final_cash, "Leaving mid-spin must immediately synchronize the wallet.")
	_check(app.run_state.bankroll == final_cash and app.run_state.grand_casino_chips == final_chips and app.run_state.rng_state == final_rng, "Scene exit must not resettle an accepted spin.")
	_check(app.enter_game("roulette"), "A mid-spin exit must permit re-entry.")
	_sample(app, app.test_msec)
	_check(not bool(app.game_surface_canvas.state.get("money_presentation_pending", true)) and app._presented_game_funds() == app.run_state.wager_capacity_for_game("roulette", app.run_state.current_environment), "Scene re-entry must keep the actual wallet and completed result.")
	_finish(app)

func _red_target(app: ClockHost) -> int:
	var state: Dictionary = app.game_surface_canvas.state
	var targets: Array = state.get("bet_targets", [])
	for i in range(targets.size()):
		if str((targets[i] as Dictionary).get("label", "")).to_upper() == "RED":
			return i
	_check(false, "Roulette must expose the normal red wager target.")
	return 0

func _sample(app: ClockHost, msec: int) -> void:
	app.test_msec = msec
	app.last_game_surface_realtime_refresh_msec = 0
	app._advance_game_surface_realtime_state()
	app._refresh_financial_hud_if_dirty()
	app._advance_presented_bankroll()
	app._flush_money_feedback()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _finish(app: ClockHost) -> void:
	if app.save_service.async_save_in_flight():
		app.save_service.wait_for_async_save()
	app.queue_free()
	print("ROULETTE_MONEY_REVEAL_RESULT " + JSON.stringify({"checks": checks, "rounds": rows, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
