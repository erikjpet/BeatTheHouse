extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const BlackjackActionAuthorityScript := preload("res://scripts/core/blackjack_action_authority.gd")
const BlackjackAuthorityTestDriverScript := preload("res://scripts/tests/foundation/blackjack_authority_test_driver.gd")

var failures: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	var definition := library.game("blackjack")
	var module_script: Script = load(str(definition.get("module_path", "")))
	var game: GameModule = module_script.new()
	game.setup(definition, library)

	var run_state: RunState = RunStateScript.new()
	run_state.start_new("BLACKJACK-WIN-PAYOUT-SETTLEMENT")
	run_state.change_bankroll(1000)
	var environment := {
		"id": "blackjack_win_payout_room",
		"display_name": "Payout Test Room",
		"depth": 1,
		"economic_profile": {"stake_floor": 1, "stake_ceiling": 100},
		"security_profile": {"strictness": "low"},
	}
	var table := game.generate_environment_state(run_state, environment, run_state.create_rng("table"))
	var original_shoe: Array = table.get("shoe", [])
	# Player 19 versus dealer 16; the dealer's next ten forces a player win.
	var forced_opening: Array = [
		{"rank": 10, "suit": 0, "deck": 91},
		{"rank": 9, "suit": 1, "deck": 91},
		{"rank": 9, "suit": 2, "deck": 91},
		{"rank": 7, "suit": 3, "deck": 91},
		{"rank": 10, "suit": 1, "deck": 92},
	]
	forced_opening.append_array(original_shoe)
	table["shoe"] = forced_opening
	table["shoe_remaining"] = forced_opening.size()
	table["patrons"] = []
	table["counting_enabled"] = false
	environment["game_states"] = {"blackjack": table}
	run_state.current_environment = environment

	var bankroll_before := run_state.bankroll
	var deal := BlackjackAuthorityTestDriverScript.surface_intent(game, "blackjack_deal", 5, run_state, environment, 0, false, 10000)
	_check(str(deal.get("action_id", "")) == "blackjack_place_bet", "Deal did not issue its sealed wager action.")
	var dealt := BlackjackAuthorityTestDriverScript.resolve_surface_command(game, deal, 5, run_state, run_state.current_environment)
	_check(bool(dealt.get("ok", false)), "Opening deal failed: %s" % JSON.stringify(dealt))

	# Reproduce a retained presentation timestamp from an older saved hand. The
	# later Stand boundary must replace it instead of waiting on the opening frame
	# forever.
	var session := _canonical_session(run_state.current_environment)
	session["surface_presentation_time_msec"] = 10000
	_stage_session(game, run_state, run_state.current_environment, session)
	var stand := BlackjackAuthorityTestDriverScript.surface_intent(game, "blackjack_stand", 5, run_state, run_state.current_environment, 0, false, 12000)
	_check(str(stand.get("action_id", "")) == "play_basic", "Stand did not cross from the finished reveal into settlement: %s" % JSON.stringify(stand))
	var result := BlackjackAuthorityTestDriverScript.resolve_surface_command(game, stand, 5, run_state, run_state.current_environment)
	_check(bool(result.get("ok", false)), "Winning hand did not settle: %s" % JSON.stringify(result))
	_check(bool(result.get("won", false)), "Forced winning hand was not reported as a win.")
	_check(int(result.get("blackjack_round_net_delta", 0)) == 5, "Winning hand did not preserve its $5 net result.")
	_check(run_state.bankroll == bankroll_before + 5, "Winning hand did not commit its payout exactly once.")
	_check(not bool(game.call("_has_dealt_hand", _canonical_session(run_state.current_environment))), "Winning hand remained active after settlement.")

	table = _table(run_state.current_environment)
	var last_result: Dictionary = table.get("last_result", {})
	var deal_events: Array = table.get("last_deal_animation_events", [])
	var patron_events: Array = table.get("last_patron_action_events", [])
	var reveal_duration := maxi(
		int(game.call("_deal_animation_duration_msec", deal_events)),
		int(game.call("_patron_action_animation_duration_msec", patron_events))
	)
	var reveal_started := int(table.get("last_deal_started_msec", 0))
	var resolved_at := int(last_result.get("resolved_at_msec", 0))
	var payout_started := int(game.call("_blackjack_payout_started_msec", last_result, reveal_started, reveal_duration))
	_check(not last_result.is_empty() and str(last_result.get("headline", "")) == "PLAYER PAID", "Settled win did not publish its payout result.")
	_check(payout_started == maxi(resolved_at, reveal_started + reveal_duration), "Payout was not scheduled after the actual final-card reveal.")

	var payout_surface := game.surface_state(run_state, run_state.current_environment, {
		"surface_time_msec": payout_started + 1,
		"surface_presentation_time_msec": payout_started + 1,
	})
	var payout_channel := _animation_channel(payout_surface, "blackjack_payout")
	_check(bool(payout_channel.get("active", false)), "Winning payout channel was not active after the final-card reveal.")
	_check(int(payout_channel.get("started_msec", 0)) == payout_started, "Winning payout channel exposed the wrong start boundary.")
	_check(bool(game.call("_blackjack_table_motion_active", table, payout_started + 1)), "Table lifecycle did not retain the active payout motion.")
	_check(not bool(game.call("_blackjack_table_motion_active", table, payout_started + 1801)), "Table lifecycle retained an expired payout motion.")

	if failures.is_empty():
		print("BLACKJACK_WIN_PAYOUT_SETTLEMENT_PROBE_PASS payout_start=%d reveal_duration=%d bankroll=%d" % [payout_started, reveal_duration, run_state.bankroll])
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _table(environment: Dictionary) -> Dictionary:
	return (environment.get("game_states", {}) as Dictionary).get("blackjack", {})


func _canonical_session(environment: Dictionary) -> Dictionary:
	var table := _table(environment)
	var binding := "blackjack:%s:%s" % [str(environment.get("id", "unknown")), str(environment.get("archetype_id", "unknown"))]
	var ledger := BlackjackActionAuthorityScript.validate_persisted_ledger(table.get(BlackjackActionAuthorityScript.LEDGER_KEY, {}), binding)
	return (ledger.get("session", {}) as Dictionary).duplicate(true)


func _stage_session(game: GameModule, run_state: RunState, environment: Dictionary, session: Dictionary) -> void:
	var table := _table(environment)
	var binding := "blackjack:%s:%s" % [str(environment.get("id", "unknown")), str(environment.get("archetype_id", "unknown"))]
	var ledger := BlackjackActionAuthorityScript.validate_persisted_ledger(
		table.get(BlackjackActionAuthorityScript.LEDGER_KEY, {}),
		binding,
		run_state.blackjack_authority_checkpoint_fingerprint()
	)
	table[BlackjackActionAuthorityScript.LEDGER_KEY] = BlackjackActionAuthorityScript.stage_session(ledger, session)
	game.call("_update_environment_table", environment, table)
	run_state.current_environment = environment


func _animation_channel(surface: Dictionary, channel_id: String) -> Dictionary:
	for channel_value in surface.get("surface_animation_channels", []):
		if typeof(channel_value) == TYPE_DICTIONARY and str((channel_value as Dictionary).get("id", "")) == channel_id:
			return channel_value as Dictionary
	return {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
