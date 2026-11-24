extends SceneTree

# Synthetic authority/cadence boundaries. Actual cold/native first-draft
# ordinary case is separate from this synthetic check.
const Blackjack := preload("res://scripts/games/blackjack.gd")
const Run := preload("res://scripts/core/run_state.gd")
const Library := preload("res://scripts/core/content_library.gd")
const Authority := preload("res://scripts/core/blackjack_action_authority.gd")
const KEY := "_blackjack_action_authority"
var checks := 0
var failures: Array[String] = []

func _init() -> void:
	var library := Library.new()
	library.load(false)
	var game := Blackjack.new()
	game.setup(library.game("blackjack"), library)
	var run := Run.new()
	run.start_new("BLACKJACK-MISSING-AUTHORITY-CADENCE")
	var environment := {"id": "cadence_fixture", "archetype_id": "riverboat_casino", "depth": 0, "economic_profile": {"stake_floor": 5, "stake_ceiling": 100}, "security_profile": {"strictness": "low"}}
	var table: Dictionary = game.generate_environment_state(run, environment, run.create_rng("table"))
	environment["game_states"] = {"blackjack": table}
	run.current_environment = environment
	table.erase(KEY)
	table["last_result"] = {"summary": "Previous hand settled."}
	table["table_round_timer_started_msec"] = 1000
	var account := [run.bankroll, run.grand_casino_chips, run.rng_state]
	var before := JSON.stringify(table)
	_check(not game._blackjack_host_needs_auto_tick(20999, run, environment), "Existing future cadence waits without authority.")
	_check(game._blackjack_host_needs_auto_tick(21000, run, environment), "Due settled cadence reaches sealed initialization without a player click.")
	_check(JSON.stringify(table) == before and [run.bankroll, run.grand_casino_chips, run.rng_state] == account, "Read-only predicate neither creates authority nor changes table/account/RNG.")
	table["table_round_timer_started_msec"] = 0
	_check(not game._blackjack_host_needs_auto_tick(21000, run, environment), "Missing authority and inactive cadence do not invent a timer.")
	table["table_round_timer_started_msec"] = 1000
	table["last_result"] = {}
	_check(not game._blackjack_host_needs_auto_tick(21000, run, environment), "New table with no settled result does not fabricate a hand.")
	table["last_result"] = {"summary": "Previous hand settled."}
	for malformed in [null, 0, "invalid"]:
		table[KEY] = malformed
		_check(not game._blackjack_host_needs_auto_tick(21000, run, environment), "Present malformed authority remains fail closed.")
	table.erase(KEY)
	table["barred"] = true
	_check(not game._blackjack_host_needs_auto_tick(21000, run, environment), "Barred table never uses missing-authority cadence.")
	table["barred"] = false
	run.challenge_config["tutorial"] = true
	_check(not game._blackjack_host_needs_auto_tick(21000, run, environment), "Tutorial still requires its explicit Deal.")
	run.challenge_config.erase("tutorial")
	table["last_result"] = {"summary": "Settled.", "payout_animation_id": "synthetic-payout", "resolved_at_msec": 20500}
	_check(not game._blackjack_host_needs_auto_tick(21000, run, environment), "Existing payout motion finishes before cadence initialization.")
	table["last_result"] = {"summary": "Previous hand settled."}
	var ledger := Authority.default_ledger("synthetic", "synthetic")
	table[KEY] = ledger
	_check(game._blackjack_host_needs_auto_tick(21000, run, environment), "Existing initialized settled authority keeps its due cadence.")
	ledger["pending_delivery"] = {"request_key": "synthetic-pending"}
	_check(not game._blackjack_host_needs_auto_tick(21000, run, environment), "Pending delivery is never bypassed by the fallback.")
	ledger["pending_delivery"] = {}
	ledger["session"] = 0
	_check(not game._blackjack_host_needs_auto_tick(21000, run, environment), "Malformed present session still fails closed.")
	ledger["session"] = {"player_hands": [{"cards": [_card(7), _card(6)], "stood": false}], "dealer_cards": [_card(9), _card(5)], "active_hand_index": 0, "bankroll_wager_debited": true, "wager_debited": 5}
	_check(not game._blackjack_host_needs_auto_tick(21000, run, environment), "Existing paid live hand cannot become a missing-authority sit-out.")
	ledger["session"]["player_hands"][0]["stood"] = true
	_check(game._blackjack_host_needs_auto_tick(21000, run, environment), "Existing completed paid hand keeps its normal settlement scheduling.")
	ledger["session"] = {}
	table["table_round_timer_started_msec"] = 21000
	_check(not game._blackjack_host_needs_auto_tick(21000, run, environment), "Existing initialized future cadence still waits.")
	table.erase(KEY)
	table["table_round_timer_started_msec"] = 1000
	var command := game.surface_auto_action_command({"surface_time_msec": 21000}, run, environment, {})
	_check(command.get("handled", false) and command.get("direct_resolve", false) and command.get("action_id", "") == "play_basic" and command.get("ui_state", {}).get("blackjack_sit_out", false), "Admitted absent-authority cadence uses the existing zero-player-wager auto command.")
	_check([run.bankroll, run.grand_casino_chips, run.rng_state] == account, "Preparing automatic cadence never transacts or draws player RNG.")
	print("BLACKJACK_MISSING_AUTHORITY_CADENCE " + JSON.stringify({"checks": checks, "failures": failures, "fixture": "synthetic module authority/cadence compatibility; actual native cold profile tested separately"}))
	quit(0 if failures.is_empty() else 1)

func _card(rank: int) -> Dictionary:
	return {"rank": rank, "suit": "clubs"}

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
