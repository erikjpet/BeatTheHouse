extends SceneTree

const Baccarat := preload("res://scripts/games/baccarat.gd")
const Canvas := preload("res://scripts/ui/game_surface_canvas.gd")
const Host := preload("res://scripts/ui/foundation_main.gd")
const Authority := preload("res://scripts/core/blackjack_action_authority.gd")
const Runtime := preload("res://scripts/core/game_ritual_runtime.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").is_empty():
		push_error("Baccarat presentation check requires an isolated BTH_DISTRIBUTION_DATA_ROOT.")
		quit(2)
		return
	var game := Baccarat.new()
	for definition in JSON.parse_string(FileAccess.get_file_as_string("res://data/games/games.json")):
		if str(definition.get("id", "")) == "baccarat":
			game.setup(definition)
	var canvas := Canvas.new()
	root.add_child(canvas)
	canvas.set_process(false)
	# Synthetic finite shoes exercise natural, both draws, Player-only and
	# Banker-only draws. No player profile or production shoe is overwritten.
	var cases := [
		{"name": "natural", "ranks": [4, 2, 5, 3], "natural": true, "draws": [false, false]},
		{"name": "both_draw", "ranks": [10, 2, 10, 2, 2, 10], "natural": false, "draws": [true, true]},
		{"name": "player_only", "ranks": [10, 2, 10, 3, 3], "natural": false, "draws": [true, false]},
		{"name": "banker_only", "ranks": [3, 2, 4, 3, 2], "natural": false, "draws": [false, true]},
	]
	for fixture in cases:
		await _check_hand(game, canvas, fixture)
	_check_fresh_deal_funding(game, canvas)
	canvas.free()
	if failures.is_empty():
		print("BACCARAT_DEAL_PRESENTATION PASS natural=true both_draw=true player_only=true banker_only=true clocks=true replay=true save_load=true repeated_deal=true auto_min_controls=true auto_paid=true auto_sitout=true fresh_funding_guard=true pending_retry=true nonunit_exchange=true")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _check_hand(game, canvas, fixture: Dictionary) -> void:
	var run := RunState.new()
	run.start_new("BACCARAT-REVEAL-%s" % fixture.name)
	run.bankroll = 1000
	run.grand_casino_chips = 200
	run.simulation_msec = 1000000
	var environment := {"id": "baccarat_reveal", "archetype_id": "grand_casino_high_limit", "kind": "boss", "game_ids": ["baccarat"], "economic_profile": {"stake_floor": 20, "stake_ceiling": 200}, "security_profile": {"strictness": "high"}}
	var table: Dictionary = game.generate_environment_state(run, environment, run.create_rng("table"))
	var shoe: Array = []
	for rank in fixture.ranks: shoe.append({"rank": rank, "suit": shoe.size() % 4, "deck": shoe.size()})
	while shoe.size() < 80: shoe.append({"rank": 2, "suit": shoe.size() % 4, "deck": shoe.size()})
	table["shoe"] = shoe
	table["shoe_remaining"] = shoe.size()
	table["cut_card_remaining"] = 4
	table["reshuffle_pending"] = false
	environment["game_states"] = {"baccarat": table}
	run.current_environment = environment
	var binding := "baccarat:baccarat_reveal:grand_casino_high_limit"
	var ledger := Authority.default_ledger(binding, run.action_authority_checkpoint_fingerprint())
	table[Authority.LEDGER_KEY] = Authority.stage_session(ledger, {"selected_chip": 20, "baccarat_bets": {"banker": 20}})
	game._update_environment_table(run.current_environment, table)
	game.enter(run, run.current_environment)
	var host := Host.new()
	host.current_game = game
	host.game_module_cache = {"baccarat": game}
	host.run_state = run
	host.selected_stake = 20
	host.game_surface_canvas = canvas
	var money_before := run.grand_casino_total_money()
	var rng_before := run.rng_state
	var result: Dictionary = host._sealed_action_host_resolve_intent("deal_baccarat", 20, {})
	_check(bool(result.get("blackjack_host_committed", false)), "%s authentic settlement" % fixture.name)
	table = game._table_state_preview(run, run.current_environment)
	var hand: Dictionary = table.get("last_hand", {})
	_check(bool(hand.get("natural", false)) == fixture.natural, "%s natural" % fixture.name)
	_check([hand.get("player_drew"), hand.get("banker_drew")] == fixture.draws, "%s tableau" % fixture.name)
	_check(run.rng_state == rng_before, "%s authored shoe RNG ownership" % fixture.name)
	_check(run.grand_casino_total_money() == money_before + int(result.get("chips_delta", result.get("bankroll_delta", 0))), "%s conservation" % fixture.name)
	var committed := Runtime.canonical_json(run.to_save_snapshot())
	_check(bool(result.get("hold_money_for_presentation", false)), "%s opts into host reveal hold" % fixture.name)
	var replay: Dictionary = host._sealed_action_host_resolve_intent("deal_baccarat", 20, result.get("blackjack_host_delivery", {}))
	_check(replay.has("blackjack_host_replay") and Runtime.canonical_json(run.to_save_snapshot()) == committed, "%s exactly-once delivery" % fixture.name)
	var start := int(table.get("last_result", {}).get("resolved_at_msec", 0))
	var state: Dictionary = game.surface_state(run, run.current_environment, {"surface_time_msec": start})
	host.last_game_result = result
	host._begin_presented_bankroll_hold(result, run.bankroll, 20)
	canvas.set_game_module(game)
	for elapsed in [0, 300, 519, 520, 1039, 1040, 1560, 2080, 2460, 2980, 3020, 3540, 4199, 4200, 4700, 5800]:
		var now := start + int(elapsed)
		var patch: Dictionary = game.surface_realtime_state_patch(run, run.current_environment, {"surface_time_msec": now}, state)
		state.merge(patch, true)
		state["surface_time_msec"] = now
		canvas.render_game_snapshot(state)
		canvas.set_process(false)
		if elapsed < 4200:
			_check(bool(state.get("money_presentation_pending", false)), "%s wallet held during deal" % fixture.name)
			_check(host._game_surface_presentation_active() and host._presented_game_funds() == money_before - 20 and host._visible_recent_bankroll_delta(19) == 0, "%s integrated host masks wallet/net" % fixture.name)
			_check(canvas.surface_animation_active("baccarat_deal"), "%s deal active at %d despite unrelated engine clock" % [fixture.name, elapsed])
			_check(absf(canvas.surface_elapsed("baccarat_deal") - float(elapsed) / 1000.0) < 0.002, "%s matching clock at %d" % [fixture.name, elapsed])
			var visible: Array = game._visible_animation_cards(canvas, state)
			var expected := 0
			for event in hand.get("animation_events", []):
				if str(event.get("type")) == "card" and int(event.delay_msec) <= elapsed: expected += 1
			_check(visible.size() == expected, "%s card count at %d" % [fixture.name, elapsed])
			_check(str(state.baccarat_explainer.winner).is_empty() and str(state.result_message).is_empty(), "%s no early result" % fixture.name)
			_check(int(state.baccarat_road.visible_count) == 0 and int(state.commission_this_hand) == 0, "%s no early road/commission" % fixture.name)
		elif elapsed < 5800:
			host._sync_presented_bankroll_to_actual()
			_check(not bool(state.get("money_presentation_pending", true)), "%s wallet released after final card" % fixture.name)
			_check(not host.presented_bankroll_hold_active and host._presented_game_funds() == run.grand_casino_total_money(), "%s integrated host reveals actual funds" % fixture.name)
			_check(canvas.surface_animation_active("baccarat_payout"), "%s payout clock" % fixture.name)
			_check(not str(state.baccarat_explainer.winner).is_empty() and int(state.baccarat_road.visible_count) == 1, "%s revealed result/road" % fixture.name)
	# Scene exit/reentry and the serialized run retain the settled receipt and
	# pause-safe timestamp; presenting it never charges or draws a second hand.
	var restored := RunState.new()
	restored.from_dict(run.to_save_snapshot())
	var resumed: Dictionary = game.surface_state(restored, restored.current_environment, {"surface_time_msec": start + 1000})
	# Foundation owns this clock field on full snapshots; modules consume it.
	resumed["surface_time_msec"] = start + 1000
	canvas.clear_runtime_state()
	canvas.render_game_snapshot(resumed)
	canvas.set_process(false)
	_check(canvas.surface_animation_active("baccarat_deal") and absf(canvas.surface_elapsed("baccarat_deal") - 1.0) < 0.002, "%s interrupted save shape resumes ceremony" % fixture.name)
	_check(Runtime.canonical_json(run.to_save_snapshot()) == committed, "%s presentation leaves accounting/RNG unchanged" % fixture.name)
	var saves := SaveService.new()
	var slot := "baccarat_reveal_%s" % fixture.name
	_check(saves.save_run(run, slot) == OK, "%s real isolated SaveService save" % fixture.name)
	var loaded: Variant = saves.load_run(slot)
	_check(loaded is RunState, "%s real isolated SaveService load" % fixture.name)
	if loaded is RunState:
		_check(loaded.grand_casino_total_money() == run.grand_casino_total_money() and loaded.rng_state == run.rng_state, "%s saved funds/RNG retained" % fixture.name)
		var loaded_table: Dictionary = game._table_state_preview(loaded, loaded.current_environment)
		# JSON restores numeric fields as floats. Compare the same serialized
		# number domain without weakening the production authority fingerprint.
		_check(Runtime.canonical_json(loaded_table.get("last_hand", {})) == Runtime.canonical_json(JSON.parse_string(JSON.stringify(hand))), "%s saved shoe/hand retained" % fixture.name)
		var loaded_surface: Dictionary = game.surface_state(loaded, loaded.current_environment, {"surface_time_msec": start + 1000})
		loaded_surface["surface_time_msec"] = start + 1000
		canvas.clear_runtime_state()
		canvas.render_game_snapshot(loaded_surface)
		canvas.set_process(false)
		_check(canvas.surface_animation_active("baccarat_deal") and absf(canvas.surface_elapsed("baccarat_deal") - 1.0) < 0.002, "%s loaded ceremony uses saved surface clock" % fixture.name)
		game.enter(loaded, loaded.current_environment)
		var reopened: Dictionary = game.surface_state(loaded, loaded.current_environment, {"surface_time_msec": start + 1000})
		_check(not bool(reopened.get("money_presentation_pending", true)) and not str(reopened.get("result_message", "")).is_empty() and bool(reopened.get("can_deal", false)), "%s normal table reentry completes already-paid presentation" % fixture.name)
	run.simulation_msec = start + 6000
	var rebet: Dictionary = host._sealed_action_host_surface_intent("baccarat_rebet", 0, false, run.simulation_msec)
	_check(bool(rebet.get("handled", false)), "%s normal rebet after ceremony" % fixture.name)
	var next_money := run.grand_casino_total_money()
	var next_result: Dictionary = host._sealed_action_host_resolve_intent("deal_baccarat", 20, {})
	_check(bool(next_result.get("blackjack_host_committed", false)) and run.grand_casino_total_money() == next_money + int(next_result.get("chips_delta", next_result.get("bankroll_delta", 0))), "%s repeated deal conserved funds" % fixture.name)

	if str(fixture.name) == "natural":
		# An invalid timed draft must remain editable, with no pending delivery.
		var guard_time := start + 20000
		run.simulation_msec = guard_time
		host._sealed_action_host_surface_intent("baccarat_clear", 0, false, guard_time)
		host._sealed_action_host_surface_intent("baccarat_chip", 0, false, guard_time)
		var guard_targets: Array = game.surface_state(run, run.current_environment, host._current_game_surface_ui_state()).get("bet_targets", [])
		var guard_player := -1
		for index in range(guard_targets.size()):
			if str((guard_targets[index] as Dictionary).get("id", "")) == "player":
				guard_player = index
				break
		host._sealed_action_host_surface_intent("baccarat_bet", guard_player, false, guard_time)
		var guard_ledger: Dictionary = host._sealed_action_host_ledger(run, false, false)
		_check(guard_player >= 0 and int((guard_ledger.get("session", {}) as Dictionary).get("baccarat_bets", {}).get("player", 0)) == 5, "timed minimum fixture stages an ordinary unpaid five-unit Player draft")
		var guard_money := run.grand_casino_total_money()
		var guard_rng := run.rng_state
		var guard_hand := Runtime.canonical_json(game._table_state_preview(run, run.current_environment).get("last_hand", {}))
		host._sealed_action_host_auto_intent(guard_time)
		run.simulation_msec = guard_time + GameModule.TABLE_ROUND_START_DELAY_MSEC + 1
		var guarded_auto: Dictionary = host._sealed_action_host_auto_intent(run.simulation_msec)
		_check(not bool(guarded_auto.get("direct_resolve", false)) and not bool(guarded_auto.get("resolve", false)), "below-minimum timer does not request a sealed hand")
		guard_ledger = host._sealed_action_host_ledger(run, false, false)
		_check((guard_ledger.get("pending_delivery", {}) as Dictionary).is_empty() and run.grand_casino_total_money() == guard_money and run.rng_state == guard_rng and Runtime.canonical_json(game._table_state_preview(run, run.current_environment).get("last_hand", {})) == guard_hand, "timed rejection leaves no delivery or money/RNG/card effect")
		var guard_clear: Dictionary = host._sealed_action_host_surface_intent("baccarat_clear", 0, false, run.simulation_msec)
		guard_ledger = host._sealed_action_host_ledger(run, false, false)
		_check(bool(guard_clear.get("handled", false)) and ((guard_ledger.get("session", {}) as Dictionary).get("baccarat_bets", {}) as Dictionary).is_empty(), "normal Clear remains usable after timed minimum rejection")

		if (guard_ledger.get("pending_delivery", {}) as Dictionary).is_empty():
			# The new guard must keep valid funded and sit-out auto hands working.
			run.simulation_msec += 1
			host._sealed_action_host_surface_intent("baccarat_chip", 2, false, run.simulation_msec)
			host._sealed_action_host_surface_intent("baccarat_bet", guard_player, false, run.simulation_msec)
			host._sealed_action_host_auto_intent(run.simulation_msec)
			run.simulation_msec += GameModule.TABLE_ROUND_START_DELAY_MSEC + 1
			var paid_before := run.grand_casino_total_money()
			var paid_auto: Dictionary = host._sealed_action_host_auto_intent(run.simulation_msec)
			var paid_delivery: Dictionary = paid_auto.get("_sealed_action_host_delivery", {})
			var paid_result: Dictionary = host._sealed_action_host_resolve_intent("deal_baccarat", int(paid_delivery.get("stake", 0)), paid_delivery)
			guard_ledger = host._sealed_action_host_ledger(run, false, false)
			_check(bool(paid_auto.get("direct_resolve", false)) and bool(paid_result.get("blackjack_host_committed", false)) and int(paid_result.get("baccarat_total_wager", -1)) == 20 and run.grand_casino_total_money() == paid_before + int(paid_result.get("chips_delta", 0)) and (guard_ledger.get("pending_delivery", {}) as Dictionary).is_empty(), "valid funded auto hand still commits its exact twenty-unit wager")
			run.simulation_msec += 6000
			host._sealed_action_host_surface_intent("baccarat_clear", 0, false, run.simulation_msec)
			host._sealed_action_host_auto_intent(run.simulation_msec)
			run.simulation_msec += GameModule.TABLE_ROUND_START_DELAY_MSEC + 1
			var sitout_before := run.grand_casino_total_money()
			var sitout_auto: Dictionary = host._sealed_action_host_auto_intent(run.simulation_msec)
			var sitout_delivery: Dictionary = sitout_auto.get("_sealed_action_host_delivery", {})
			var sitout_result: Dictionary = host._sealed_action_host_resolve_intent("deal_baccarat", int(sitout_delivery.get("stake", 0)), sitout_delivery)
			guard_ledger = host._sealed_action_host_ledger(run, false, false)
			_check(bool(sitout_auto.get("direct_resolve", false)) and bool(sitout_result.get("blackjack_host_committed", false)) and bool(sitout_result.get("baccarat_sat_out", false)) and int(sitout_result.get("baccarat_total_wager", -1)) == 0 and run.grand_casino_total_money() == sitout_before and (guard_ledger.get("pending_delivery", {}) as Dictionary).is_empty(), "valid automatic sit-out hand keeps zero stake and no pending delivery")
	host.free()


# Synthetic recovery regression, not normal UI proof.
# The first fixture mirrors the observed working110 loss to cash33/chips15.
func _check_fresh_deal_funding(game, canvas) -> void:
	for fixture in [
		{"name": "working110", "cash": 33, "chips": 125, "bet": 110, "minimum": 110, "rate": 1},
		{"name": "exchange3", "cash": 75, "chips": 95, "bet": 80, "minimum": 20, "rate": 3},
	]:
		var run := RunState.new()
		run.start_new("BACCARAT-FRESH-FUNDING-%s" % fixture.name)
		run.bankroll = int(fixture.cash)
		run.grand_casino_chips = int(fixture.chips)
		run.simulation_msec = 1000000
		var environment := {"id": "baccarat_fresh_funding", "archetype_id": "grand_casino_high_limit", "kind": "boss", "game_ids": ["baccarat"], "economic_profile": {"stake_floor": int(fixture.minimum), "stake_ceiling": 200}, "security_profile": {"strictness": "high"}, "local_narrative_flags": {"casino_chip_cash_rate": int(fixture.rate)}}
		var table: Dictionary = game.generate_environment_state(run, environment, run.create_rng("table"))
		# Mandatory natural Banker9 beats Player1; the paid hand creates the shortfall.
		var shoe: Array = []
		for rank in [10, 4, 1, 5]:
			shoe.append({"rank": rank, "suit": shoe.size() % 4, "deck": 0})
		while shoe.size() < 80:
			shoe.append({"rank": 2, "suit": shoe.size() % 4, "deck": 0})
		table["shoe"] = shoe
		table["shoe_remaining"] = shoe.size()
		table["cut_card_remaining"] = 4
		table["reshuffle_pending"] = false
		environment["game_states"] = {"baccarat": table}
		run.current_environment = environment
		var binding := RunState.action_authority_table_binding("baccarat", environment)
		var ledger := Authority.default_ledger(binding, run.action_authority_checkpoint_fingerprint())
		table[Authority.LEDGER_KEY] = Authority.stage_session(ledger, {"selected_chip": 10, "selected_stake": 10, "baccarat_bets": {"player": int(fixture.bet)}})
		game._update_environment_table(run.current_environment, table)
		game.enter(run, run.current_environment)
		var host := Host.new()
		host.current_game = game
		host.game_module_cache = {"baccarat": game}
		host.run_state = run
		host.selected_stake = 10
		host.game_surface_canvas = canvas
		host.current_game_state_key = "baccarat"
		game.set_transient_state_key_context("baccarat")
		host._set_active_game_binding("baccarat")
		var initial := _funding_guard_observation(run)
		var funded_preview := run.preview_grand_casino_wager_funding("baccarat", int(fixture.bet), run.current_environment)
		_check(bool(funded_preview.get("ok", false)) and int(funded_preview.get("existing_chips_used", 0)) == int(fixture.bet) and int(funded_preview.get("cash_used", -1)) == 0 and Runtime.canonical_json(_funding_guard_observation(run)) == Runtime.canonical_json(initial), "%s funded preview is pure and uses existing chips" % fixture.name)
		var staged: Dictionary = host._sealed_action_host_surface_intent("baccarat_deal", 0, false, run.simulation_msec)
		var issued: Dictionary = staged.get("_sealed_action_host_delivery", {})
		_check(bool(staged.get("resolve", false)) and not issued.is_empty() and Runtime.canonical_json(_funding_guard_observation(run)) == Runtime.canonical_json(initial), "%s fresh affordable deal publishes delivery without funding or resolution" % fixture.name)
		# Exercise the real pending-retry branch before first delivery is resolved.
		var retry: Dictionary = host._sealed_action_host_surface_intent("table_game_retry_pending", 0, false, run.simulation_msec)
		var retry_delivery: Dictionary = retry.get("_sealed_action_host_delivery", {})
		_check(bool(retry.get("direct_resolve", false)) and not issued.is_empty() and str(retry_delivery.get("request_key", "")) == str(issued.get("request_key", "")), "%s legitimate pending retry retains its exact request" % fixture.name)
		var paid: Dictionary = host._sealed_action_host_resolve_intent("deal_baccarat", int(retry_delivery.get("stake", 0)), retry_delivery)
		table = game._table_state_preview(run, run.current_environment)
		if not bool(paid.get("blackjack_host_committed", false)):
			print("BACCARAT_FRESH_FUNDING_REJECTION " + JSON.stringify({"fixture": str(fixture.name), "error_code": str(paid.get("error_code", "")), "message": str(paid.get("message", "")), "diagnostic_detail": str(paid.get("diagnostic_detail", "")), "request_key": str(paid.get("request_key", ""))}))
		_check(bool(paid.get("blackjack_host_committed", false)) and int(paid.get("blackjack_host_wager_cost", -1)) == int(fixture.bet) and int(table.get("hands_played", 0)) == 1 and str(table.get("last_result", {}).get("winner", "")) == "banker" and run.bankroll == int(fixture.cash) and run.grand_casino_chips == 15, "%s funded pending retry settles its one losing hand" % fixture.name)
		var completed: Dictionary = host._sealed_action_host_ledger(run, false, false)
		_check((completed.get("pending_delivery", {}) as Dictionary).is_empty() and (completed.get("request_cache", {}) as Dictionary).size() == 1 and (completed.get("journal", []) as Array).size() == 1 and int((completed.get("session", {}) as Dictionary).get("baccarat_bets", {}).get("player", 0)) == int(fixture.bet), "%s completed hand keeps working bets and one committed receipt" % fixture.name)
		run.simulation_msec = int(table.get("last_result", {}).get("resolved_at_msec", 0)) + 6000
		var rejected_before := _funding_guard_observation(run)
		var unfunded_preview := run.preview_grand_casino_wager_funding("baccarat", int(fixture.bet), run.current_environment)
		_check(not bool(unfunded_preview.get("ok", true)) and Runtime.canonical_json(_funding_guard_observation(run)) == Runtime.canonical_json(rejected_before), "%s insufficient funding preview is pure" % fixture.name)
		if int(fixture.rate) > 1:
			_check(run.bankroll + run.grand_casino_chips >= int(fixture.bet), "exchange3 refusal cannot be replaced by nominal cash-plus-chips check")
		var refused: Dictionary = host._sealed_action_host_surface_intent("baccarat_deal", 0, false, run.simulation_msec)
		_check(bool(refused.get("handled", false)) and str(refused.get("message", "")) == str(unfunded_preview["message"]), "%s manual refusal is the exact funding preflight response" % fixture.name)
		_check(not bool(refused.get("resolve", false)) and not bool(refused.get("direct_resolve", false)) and not refused.has("_sealed_action_host_delivery"), "%s unaffordable manual draft is refused before delivery" % fixture.name)
		host._sealed_action_host_auto_intent(run.simulation_msec)
		var armed_timer := GameModule.table_round_timer_status_peek(game._table_state_preview(run, run.current_environment), run.simulation_msec, "Next hand", GameModule.TABLE_ROUND_START_DELAY_MSEC, false)
		_check(bool(armed_timer.get("active", false)) and not bool(armed_timer.get("due", true)), "%s first auto probe really starts a not-yet-due timer" % fixture.name)
		run.simulation_msec += GameModule.TABLE_ROUND_START_DELAY_MSEC + 1
		var due_timer := GameModule.table_round_timer_status_peek(game._table_state_preview(run, run.current_environment), run.simulation_msec, "Next hand", GameModule.TABLE_ROUND_START_DELAY_MSEC, false)
		_check(bool(due_timer.get("active", false)) and bool(due_timer.get("due", false)), "%s second auto probe reaches the existing due timer" % fixture.name)
		var refused_auto: Dictionary = host._sealed_action_host_auto_intent(run.simulation_msec)
		var after: Dictionary = host._sealed_action_host_ledger(run, false, false)
		_check(bool(refused_auto.get("handled", false)) and str(refused_auto.get("message", "")) == str(unfunded_preview["message"]), "%s timed refusal is the exact funding preflight response" % fixture.name)
		_check(not bool(refused_auto.get("resolve", false)) and not bool(refused_auto.get("direct_resolve", false)) and not refused_auto.has("_sealed_action_host_delivery") and (after.get("pending_delivery", {}) as Dictionary).is_empty(), "%s unaffordable timed draft is refused before delivery" % fixture.name)
		_check(int(after.get("boundary_ordinal", -1)) == int(completed.get("boundary_ordinal", -2)) and int(after.get("next_request_ordinal", -1)) == int(completed.get("next_request_ordinal", -2)) and Runtime.canonical_json(after.get("request_cache", {})) == Runtime.canonical_json(completed.get("request_cache", {})) and Runtime.canonical_json(after.get("journal", [])) == Runtime.canonical_json(completed.get("journal", [])), "%s refusal creates no request or committed receipt" % fixture.name)
		_check(Runtime.canonical_json(_funding_guard_observation(run)) == Runtime.canonical_json(rejected_before), "%s refusal preserves funds RNG inventory shoe hand history and money story" % fixture.name)
		_check(int((after.get("session", {}) as Dictionary).get("baccarat_bets", {}).get("player", 0)) == int(fixture.bet), "%s unaffordable working bets stay editable and are not cleared" % fixture.name)
		var cleared: Dictionary = host._sealed_action_host_surface_intent("baccarat_clear", 0, false, run.simulation_msec)
		var cleared_ledger: Dictionary = host._sealed_action_host_ledger(run, false, false)
		_check(bool(cleared.get("handled", false)) and ((cleared_ledger.get("session", {}) as Dictionary).get("baccarat_bets", {}) as Dictionary).is_empty() and (cleared_ledger.get("pending_delivery", {}) as Dictionary).is_empty(), "%s normal Clear remains usable after funding refusal" % fixture.name)
		host.free()


func _funding_guard_observation(run: RunState) -> Dictionary:
	# Timer/session presentation may advance; these economic/game-result fields may not.
	var table: Dictionary = run.current_environment.get("game_states", {}).get("baccarat", {})
	return {"cash": run.bankroll, "chips": run.grand_casino_chips, "rng_seed": run.rng_seed, "rng_state": run.rng_state, "inventory": run.inventory.duplicate(true), "story": run.story_log.duplicate(true), "story_archive_count": run.story_log_archive_count, "money_archive": run.story_money_archive.duplicate(true), "hands_played": table.get("hands_played", 0), "shoe": (table.get("shoe", []) as Array).duplicate(true), "last_hand": (table.get("last_hand", {}) as Dictionary).duplicate(true), "last_result": (table.get("last_result", {}) as Dictionary).duplicate(true), "hand_history": (table.get("hand_history", []) as Array).duplicate(true)}


func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
