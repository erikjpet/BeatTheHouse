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
	canvas.free()
	if failures.is_empty():
		print("BACCARAT_DEAL_PRESENTATION PASS natural=true both_draw=true player_only=true banker_only=true clocks=true replay=true save_load=true repeated_deal=true")
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
	host.free()


func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
