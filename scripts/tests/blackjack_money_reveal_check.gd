extends SceneTree

const Main := preload("res://scripts/ui/foundation_main.gd")
const Blackjack := preload("res://scripts/games/blackjack.gd")

class ClockHost extends Main:
	var test_msec := 100000
	func _environment_simulation_time_msec() -> int: return test_msec
	func _current_game_surface_input_time_msec() -> int: return test_msec
	func _game_test_archetype() -> Dictionary:
		if OS.get_cmdline_user_args().has("--cash"):
			for value in library.environment_archetypes:
				if str((value as Dictionary).get("id", "")) == "bar": return (value as Dictionary).duplicate(true)
		return super._game_test_archetype()

class QuietAudio extends Node:
	var signs: Array = []
	func play_money_feedback(amount: int) -> bool:
		signs.append(amount)
		return true

var checks := 0
var failures: Array[String] = []
var rows: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var app := ClockHost.new()
	app.continuous_environment_clock_enabled = false
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_process(false)
	var start: Dictionary = app.start_game_test_session("blackjack")
	_check(bool(start.get("ok", false)), "Normal host test session enters Blackjack.")
	if not bool(start.get("ok", false)):
		_finish(app)
		return
	var audio := QuietAudio.new()
	if app.environment_sfx_player != null: app.environment_sfx_player.queue_free()
	app.environment_sfx_player = audio
	app.add_child(audio)
	# Preserve the legacy boolean contract used by Roulette and Baccarat.
	var original_state: Dictionary = app.game_surface_canvas.state
	app.presented_bankroll_hold_active = true
	app.game_surface_canvas.state = {"money_presentation_pending": true}
	_check(app._game_surface_presentation_active(), "Existing boolean reveal owners retain their pending gate.")
	app.game_surface_canvas.state = {"money_presentation_pending": false}
	_check(not app._game_surface_presentation_active(), "Existing boolean reveal owners retain their completed gate.")
	app.game_surface_canvas.state = original_state
	app._clear_presented_bankroll_hold()
	for round_index in range(6):
		_sample(app, 100000 + round_index * 30000)
		var before := app.run_state.wager_capacity_for_game("blackjack", app.run_state.current_environment)
		app._on_game_surface_action("blackjack_deal", 0)
		for frame in range(12): await process_frame
		_sample(app, app.test_msec + 5000)
		await process_frame
		app._on_game_surface_action("blackjack_stand", 0)
		for frame in range(12): await process_frame
		var result: Dictionary = app.last_game_result.duplicate(true)
		var state: Dictionary = app.game_surface_canvas.state
		rows.append({"round": round_index, "before": before, "actual": app.run_state.wager_capacity_for_game("blackjack", app.run_state.current_environment),
			"result_action": result.get("action_id"), "hand_results": result.get("blackjack_hand_results", []),
			"hold": app.presented_bankroll_hold_active, "start": state.get("deal_started_msec"),
			"duration": state.get("deal_animation_duration_msec"), "phase": state.get("phase"),
			"cash": app.run_state.bankroll, "chips": app.run_state.grand_casino_chips, "rng": str(app.run_state.rng_state)})
		_check(not (result.get("blackjack_hand_results", []) as Array).is_empty(), "Normal Deal/Stand settles one accepted hand.")
		if (result.get("blackjack_hand_results", []) as Array).is_empty(): break
		var actual := app.run_state.wager_capacity_for_game("blackjack", app.run_state.current_environment)
		var cash := app.run_state.bankroll
		var chips := app.run_state.grand_casino_chips
		var rng := app.run_state.rng_state
		var returned := int(result.get("blackjack_settlement_return_delta", 0))
		_check(actual == before + int(result.get("blackjack_round_net_delta", 0)), "Accepted hand accounts its net result exactly once.")
		var started := int(state.get("deal_started_msec", 0))
		var duration := int(state.get("deal_animation_duration_msec", 0))
		var sounds := audio.signs.size()
		_check(duration > 0, "Accepted settlement has an existing finite card reveal.")
		_sample(app, started + maxi(0, duration - 1))
		_check(app.presented_bankroll_hold_active, "Wallet outcome remains held before final card.")
		_check(app._presented_game_funds() == actual - returned, "Wallet hides the accepted return before final card.")
		_check(int(app.game_surface_canvas.state.get("bankroll", -1)) == actual - returned, "Table funds do not overwrite masked wallet.")
		_check(app._current_game_result_snapshot().is_empty(), "Generic result cannot spoil dealer reveal.")
		_check(audio.signs.size() == sounds, "Money sound cannot expose the accepted return before final card.")
		_check(app.run_state.bankroll == cash and app.run_state.grand_casino_chips == chips and app.run_state.rng_state == rng, "Presentation leaves committed money/RNG unchanged.")
		if round_index == 3:
			app.game_surface_canvas.reduce_motion = true
			_sample(app, started + maxi(0, duration - 1))
			_check(not app.presented_bankroll_hold_active and app._presented_game_funds() == actual, "Reduced motion reveals without waiting for disabled animation.")
			app.game_surface_canvas.reduce_motion = false
		elif round_index == 4:
			app.autosave_slot_id = "blackjack-money-reveal"
			_check(app.save_service.save_run(app.run_state, app.autosave_slot_id) == OK, "Mid-reveal Save persists accepted settlement.")
			_check(app.load_foundation_run(), "Normal Continue accepts the mid-reveal saved hand.")
			_check(not app.presented_bankroll_hold_active and app._presented_bankroll() == cash, "Continue shows committed cash without an old reveal hold.")
			_check(app.run_state.bankroll == cash and app.run_state.grand_casino_chips == chips and app.run_state.rng_state == rng, "Continue preserves money and RNG exactly.")
			_check(app.enter_game("blackjack"), "Saved settled table can re-enter.")
			_check(not app.presented_bankroll_hold_active and app._presented_game_funds() == actual, "Re-entry cannot replay historical wallet masking.")
		elif round_index == 5:
			app.back_to_environment()
			_check(not app.presented_bankroll_hold_active and app._presented_bankroll() == cash, "Scene exit releases only presentation, retaining accepted cash.")
			_check(app.run_state.bankroll == cash and app.run_state.grand_casino_chips == chips and app.run_state.rng_state == rng, "Scene exit cannot resettle or draw RNG.")
			_check(app.enter_game("blackjack") and not app.presented_bankroll_hold_active, "Scene re-entry remains usable without replaying the hold.")
		_sample(app, started + duration)
		_check(not app.presented_bankroll_hold_active and app._presented_game_funds() == actual, "Final-card boundary releases accepted wallet.")
		var released_sounds := audio.signs.size()
		_sample(app, started + duration + 1)
		_check(app.run_state.bankroll == cash and app.run_state.grand_casino_chips == chips and app.run_state.rng_state == rng, "Repeated reveal frame cannot resettle or draw RNG.")
		_check(audio.signs.size() == released_sounds, "Repeated reveal frame cannot repeat payout feedback audio.")
	_finish(app)

func _sample(app: ClockHost, msec: int) -> void:
	app.test_msec = msec
	app.game_surface_canvas.surface_simulation_clock_msec = msec
	app.game_surface_canvas.surface_presentation_clock_msec = msec
	app._advance_presented_bankroll()
	app._refresh_financial_hud_if_dirty()
	app._flush_money_feedback()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _finish(app: ClockHost) -> void:
	if app.save_service.async_save_in_flight(): app.save_service.wait_for_async_save()
	app.free()
	print("BLACKJACK_MONEY_REVEAL_RESULT " + JSON.stringify({"checks": checks, "rows": rows, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
