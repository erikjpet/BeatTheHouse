extends SceneTree

const MAIN := preload("res://scripts/ui/foundation_main.gd")
const SEED := "CORE-MONEY"

# Play on the actual Foundation host; direct module simulation cannot commit
# a sealed table action. We advance its presentation clock rather than wait
# for cosmetic sequences, so action legality and settlement stay production.
class TestHost extends MAIN:
	var test_time := 100000
	var test_game := ""

	func _environment_simulation_time_msec() -> int:
		return test_time

	func _game_test_archetype() -> Dictionary:
		var venue := "grand_casino" if test_game in ["blackjack", "baccarat", "craps", "roulette"] else "bar"
		return library.environment_archetype(venue)

	func _prepare_game_test_prerequisites(game_id: String, environment: Dictionary) -> void:
		super._prepare_game_test_prerequisites(game_id, environment)
		# Fund the two real wallets before the game binds its authority.
		run_state.grand_casino_chips = 100

	func _game_test_seed(game_id: String) -> String:
		return SEED + "-" + game_id


var app: TestHost
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	app = TestHost.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.user_settings.coach_tips_enabled = false
	app._ensure_full_content_library_loaded()
	for definition in app.library.games:
		var game_id := str(definition["id"])
		if not OS.get_cmdline_user_args().is_empty() and not game_id in OS.get_cmdline_user_args():
			continue
		var uninterrupted := await _play(game_id, false)
		var restored := await _play(game_id, true)
		if not uninterrupted.is_empty() and not restored.is_empty() and uninterrupted != restored:
			_fail(game_id, "settlement differs after restore: %s vs %s" % [uninterrupted, restored])
	app.pending_autosave = false
	app.save_service.wait_for_async_save()
	for _frame in range(5):
		await process_frame
	app.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _play(game_id: String, reload: bool) -> Dictionary:
	app.close_game_test_menu()
	app.test_game = game_id
	var opened := app.start_game_test_session(game_id)
	if not bool(opened.get("ok", false)):
		_fail(game_id, "host could not enter seeded session: " + str(opened.get("errors", [])))
		return {}
	app.game_surface_canvas.set_process(false)
	await _tick()
	var run := app.run_state
	var game := app.current_game
	var before := _account()
	var initial_history := run.story_log.size()
	var offered := game.actions(run, run.current_environment)
	if not offered.get("ok", false) or game.legal_actions(run, run.current_environment).is_empty():
		_fail(game_id, "entered game offers no legal action")
		return {}
	var boundary := await _begin(game_id, offered)
	if boundary.is_empty():
		return {}
	var saved_account := _account()
	# The host's ordinary save boundary checkpoints the module's UI-local
	# session into RunState. The package never needs a player save or disk.
	app._prepare_foundation_run_save()
	var snapshot := app.run_state.to_dict().duplicate(true)
	if _account() != saved_account:
		_fail(game_id, "checkpoint moved money/items or appended a game entry")
	if reload and not await _restore(game_id, snapshot, saved_account):
		return {}
	if not await _finish(game_id, boundary):
		return {}
	var settled := _account()
	var observed_result := app.last_game_result.duplicate(true)
	var progressed := app.run_state.story_log.size() > initial_history or settled != before
	if not progressed or not bool(observed_result.get("ok", false)):
		_fail(game_id, "no accepted paid action or settlement: " + _message())
		return {}
	if not _accounted(game_id, before, initial_history, settled):
		return {}
	# A second restore after settlement must not debit/credit the hand again.
	app._prepare_foundation_run_save()
	var settled_save := app.run_state.to_dict().duplicate(true)
	var check := RunState.new()
	check.from_dict(settled_save)
	if _account(check) != settled:
		_fail(game_id, "restoring already settled state duplicates or loses a settlement")
		return {}
	return settled


func _restore(game_id: String, snapshot: Dictionary, expected: Dictionary) -> bool:
	var fresh := RunState.new()
	fresh.from_dict(snapshot)
	if _account(fresh) != expected:
		_fail(game_id, "fresh RunState changed cash, chips, items, or history")
		return false
	app._reset_game_surface_runtime_state(false)
	app.current_game = null
	app.run_state = fresh
	app._bind_run_state_presentation_signals()
	app._refresh_run_action_service()
	app._set_current_screen(app.SCREEN_ENVIRONMENT)
	if not app.enter_game(game_id):
		_fail(game_id, "resuming saved game failed: " + _message())
		return false
	await _tick()
	return true


func _begin(game_id: String, offered: Dictionary) -> Dictionary:
	if game_id in ["roulette", "baccarat"]:
		var target := "red" if game_id == "roulette" else "banker"
		var index := _target_index(game_id, target)
		if index < 0:
			_fail(game_id, "could not find legal target " + target)
			return {}
		var view: Dictionary = app.game_surface_canvas.state
		var stake := int(view.get("table_minimum", view.get("rules", {}).get("outside_min_each", offered.get("stake_floor", 1))))
		var chips: Array = app.game_surface_canvas.state.get("chip_denominations", [])
		var chip_index := chips.find(stake)
		if chip_index < 0:
			chip_index = 0
		if chips.is_empty():
			_fail(game_id, "could not find legal chip")
			return {}
		await _click(game_id + "_chip", chip_index)
		for _step in range(ceili(float(stake) / float(chips[chip_index]))):
			await _click(game_id + "_bet", index)
		if game_id == "roulette":
			await _click("roulette_spin")
		return {"paid_on_finish": true}
	if game_id == "bar_dice":
		for action in ["bar_dice_stake", "bar_dice_roll", "bar_dice_ack_cover", "bar_dice_shake",
				"bar_dice_shake", "bar_dice_resolve", "bar_dice_throw"]:
			await _click(action)
		return {"paid_on_finish": true}
	if game_id == "blackjack":
		await _click("blackjack_deal")
		return {"paid": true}
	if game_id == "video_poker":
		await _click("video_poker_deal")
		return {"paid_on_finish": true}
	if game_id == "crew_draw_poker":
		# Ordered Hold'em may not post a blind from the player's first seat.
		app._resolve_game_action("deal", true, true)
		await _tick()
		for _step in range(8):
			var poker_ids := _legal_ids()
			if "call" in poker_ids or "fold" in poker_ids:
				var run := app.run_state
				var game := app.current_game
				for action in ["call", "raise"]:
					if action in poker_ids and game.wager_cost_for_context(action, 1, run, run.current_environment, app._current_game_surface_ui_state()) > 0:
						var cash := run.bankroll
						app._resolve_game_action(action, true, true)
						await _tick()
						if app.run_state.bankroll < cash:
							return {"paid": true}
				break
			if "observe" not in poker_ids:
				break
			app._resolve_game_action("observe", true, true)
			await _tick()
		_fail(game_id, "could not reach live Hold’em decisions: " + str(_legal_ids()))
		return {}
	if game_id == "craps":
		# The generated venue's actual pass-line minimum can exceed the test room floor.
		var view: Dictionary = app.game_surface_canvas.state
		var stake := int(view.get("table_minimum", 5))
		var ui := app._current_game_surface_ui_state()
		ui["craps_pending_bets"] = {"pass_line": stake}
		app._resolve_game_action("roll_craps", true, true, false, ui, false, stake)
		await _tick()
		if not bool(app.last_game_result.get("ok", false)):
			_fail(game_id, "paid Pass wager rejected: " + _message())
			return {}
		return {"paid": true}
	var run := app.run_state
	var game := app.current_game
	var stake := maxi(1, int(offered.get("stake_floor", 1)))
	var ui := app._current_game_surface_ui_state()
	for row in offered.get("legal_actions", []):
		var id := str(row.get("id", ""))
		if id.is_empty() or game.wager_cost_for_context(id, stake, run, run.current_environment, ui) <= 0:
			continue
		app._resolve_game_action(id, false, true, false, {}, false, stake)
		await process_frame
		if not bool(app.last_game_result.get("ok", false)):
			_fail(game_id, "paid action %s was rejected: %s" % [id, _message()])
			return {}
		if game_id == "coin_pusher" and not _settle_pusher():
			return {}
		return {"paid": true}
	_fail(game_id, "no paid action in the module's legal actions")
	return {}


func _finish(game_id: String, _boundary: Dictionary) -> bool:
	match game_id:
		"blackjack":
			# Let the dealt cards finish before attempting the live decision.
			for _step in range(8):
				if not _incomplete():
					break
				await _tick()
				app._advance_game_surface_automation()
				var view: Dictionary = app.game_surface_canvas.state
				if bool(view.get("can_stand", false)):
					await _click("blackjack_stand")
					break
		"baccarat":
			await _click("baccarat_deal")
		"roulette":
			await _click("roulette_spin")
		"bar_dice":
			await _click("bar_dice_reveal")
			await _click("bar_dice_ack_call")
		"video_poker":
			await _click("video_poker_draw")
		"scratch_tickets":
			await _click("scratch_collect_tray")
			await _click("scratch_all")
			await _click("scratch_file_ticket")
		"pull_tabs":
			await _click("pull_tab_collect_tray")
			await _click("pull_tab_auto_open")
		"crew_draw_poker":
			for _step in range(16):
				if not _incomplete():
					break
				var ids := _legal_ids()
				var action := ""
				for candidate in ["fold", "observe", "call", "draw"]:
					if candidate in ids:
						action = candidate
						break
				if action.is_empty():
					break
				app._resolve_game_action(action, true, true)
				await _tick()
			if "cash_out" in _legal_ids():
				app._resolve_game_action("cash_out", true, true)
				await _tick()
		"craps":
			for _step in range(20):
				var view: Dictionary = app.game_surface_canvas.state
				if int(view.get("point", 0)) == 0:
					break
				var ui := app._current_game_surface_ui_state()
				ui["craps_pending_bets"] = {}
				app._resolve_game_action("roll_craps", true, true, false, ui)
				await _tick()
			if int(app.game_surface_canvas.state.get("point", 0)) != 0:
				_fail(game_id, "paid Pass wager did not settle")
				return false
	for _step in range(25):
		await _tick()
		app._advance_game_surface_automation()
		if not _incomplete() and game_id not in ["scratch_tickets", "pull_tabs"]:
			break
	if _incomplete():
		_fail(game_id, "round remained open: " + _message())
		return false
	return true


func _legal_ids() -> Array:
	return app.current_game.legal_actions(app.run_state, app.run_state.current_environment).map(func(row): return row.get("id", ""))


func _settle_pusher() -> bool:
	# Production Save is unavailable until the paid drop has reached a durable
	# physics checkpoint. Never serialize or invent an unsupported live state.
	var game := app.current_game
	var run := app.run_state
	var room := run.current_environment
	if not game.requires_chunked_exit_settle(run, room):
		return true
	game.begin_chunked_exit_settle(run, room)
	for _step in range(80):
		if bool(game.advance_chunked_exit_settle(run, room, 32).get("done", false)):
			game.finalize_chunked_exit_settle(run, room)
			return game.foundation_save_ready(run, room)
	_fail("coin_pusher", "paid drop did not settle to a durable checkpoint")
	return false


func _target_index(game_id: String, target: String) -> int:
	var view: Dictionary = app.game_surface_canvas.state
	var rows: Array = view.get("bet_targets", [])
	for index in range(rows.size()):
		if str(rows[index].get("id", "")) == target or str(rows[index].get("type", "")) == target:
			return index
	# Baccarat's felt exposes a fixed list of player/banker/tie regions.
	if game_id == "baccarat" and target == "banker":
		return 4
	return -1


func _accounted(game_id: String, before: Dictionary, start: int, after: Dictionary) -> bool:
	# Hold'em settles the table's session swing rather than writing game_action
	# rows for individual betting decisions.
	if game_id == "crew_draw_poker":
		var table: Dictionary = app.run_state.current_environment.get("game_states", {}).get(game_id, {})
		if not bool(table.get("session_settled", false)) or int(table.get("hand_number", 0)) != 1 				or after.cash != before.cash + int(table.get("session_swing", 0)) or after.chips != before.chips:
			_fail(game_id, "expected one settled Hold’em hand and exact session swing: " + _message())
			return false
		return true
	var count := 0
	var currency := GameModule.presentation_currency_for_game(app.run_state, game_id, app.run_state.current_environment)
	var cash_delta := 0
	var chips_delta := 0
	for entry in app.run_state.story_log.slice(start):
		if entry.get("type", "") != "game_action" or entry.get("game_id", "") != game_id:
			continue
		count += 1
		cash_delta += int(entry.get("bankroll_delta", 0))
		chips_delta += int(entry.get("chips_delta", 0)) if currency == "chips" else 0
		if currency == "chips" and entry.get("currency", "") == "chips":
			cash_delta -= int(entry.get("bankroll_delta", 0))
			chips_delta += int(entry.get("currency_delta", entry.get("chips_delta", 0))) - int(entry.get("chips_delta", 0))
	if count == 0:
		_fail(game_id, "no journaled paid outcome was recorded")
		return false
	if before.cash + cash_delta != after.cash or before.chips + chips_delta != after.chips:
		_fail(game_id, "wallet totals differ from per-action net: %s + %s/%s != %s" % [before, cash_delta, chips_delta, after])
		return false
	return true


func _account(run: RunState = null) -> Dictionary:
	var source := app.run_state if run == null else run
	return {"cash": source.bankroll, "chips": source.grand_casino_chips, "items": source.inventory.duplicate(true),
		"entries": source.story_log.filter(func(row): return row.get("type", "") == "game_action").size()}


func _click(action: String, index: int = 0) -> void:
	app._on_game_surface_action(action, index)
	await _tick()


func _tick() -> void:
	app.test_time += 2000
	var canvas: Control = app.game_surface_canvas
	canvas.surface_simulation_clock_msec = app.test_time
	canvas.surface_presentation_clock_msec = app.test_time
	app.last_game_surface_realtime_refresh_msec = 0
	app._advance_game_surface_realtime_state()
	await process_frame


func _incomplete() -> bool:
	return app.current_game != null and app.current_game.wager_activity_incomplete(
		app.run_state, app.run_state.current_environment, app._current_game_surface_ui_state())


func _message() -> String:
	return str(app.last_game_result.get("message", "")) + " / " + str(app.message_label.text)


func _fail(game_id: String, detail: String) -> void:
	failures.append(game_id + ": " + detail)
