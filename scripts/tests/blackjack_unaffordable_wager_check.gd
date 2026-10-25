extends SceneTree

const Blackjack := preload("res://scripts/games/blackjack.gd")
const Run := preload("res://scripts/core/run_state.gd")
const Library := preload("res://scripts/core/content_library.gd")
var checks := 0
var failures: Array[String] = []

func _init() -> void:
	var library := Library.new()
	library.load(false)
	var game := Blackjack.new()
	game.setup(library.game("blackjack"), library)
	var run := Run.new()
	run.start_new("BLACKJACK-UNAFFORDABLE-PRESENTATION")
	run.change_bankroll(10 - run.bankroll)
	var environment := {"id": "affordability_fixture", "archetype_id": "riverboat_casino", "depth": 0, "economic_profile": {"stake_floor": 11, "stake_ceiling": 100}, "security_profile": {"strictness": "low"}}
	environment["game_states"] = {"blackjack": game.generate_environment_state(run, environment, run.create_rng("table"))}
	run.current_environment = environment
	var cash := run.bankroll
	var rng := run.rng_state
	var low := game.surface_state(run, environment, {"selected_stake": 0})
	_check(bool(low.get("wager_blocked", false)), "Ten cannot fund the authored eleven minimum.")
	_check(not bool(low.get("can_deal", true)), "Unfundable new hand must not advertise DEAL.")
	_check(int(low.get("minimum_wager", 0)) == 11, "Projection retains the authored minimum.")
	_check(str(low.get("table_notice", "")).contains("11") and str(low.get("table_notice", "")).contains("10"), "Table explains minimum and available funds.")
	_check(bool(low.get("surface_animates_idle", false)), "Unfundable table retains autonomous idle animation.")
	_check(run.bankroll == cash and run.rng_state == rng, "Reading the blocked view changes neither money nor RNG.")
	var actions := game._blackjack_ritual_action_states(low, "wagering")
	_check(not bool(actions.blackjack_deal.enabled), "Pointer/keyboard ritual projection also disables unaffordable deal.")
	run.change_bankroll(1)
	var enough := game.surface_state(run, environment, {"selected_stake": 11})
	_check(not bool(enough.get("wager_blocked", true)) and bool(enough.get("can_deal", false)), "Exact minimum funds a normal new hand.")
	_check(not str(enough.get("table_notice", "")).contains("available"), "Fundable table retains ordinary instructions.")
	var chip := game.surface_action_command("blackjack_chip", 0, false, {"selected_stake": 11}, run, environment)
	_check(chip.get("handled", false) and int(chip.get("set_stake", 0)) == 11 and run.bankroll == 11, "Normal funded chip staging remains available and costs nothing before deal.")
	# Synthetic live-hand presentation: already committed money must not disable
	# Hit/Stand or settlement when the remaining wallet is below a new minimum.
	run.change_bankroll(-run.bankroll)
	var hand := {"cards": [_card(7, "clubs"), _card(6, "spades")], "stood": false}
	var session := {"selected_stake": 11, "player_hands": [hand], "dealer_cards": [_card(9, "hearts"), _card(5, "clubs")], "active_hand_index": 0, "wager_debited": true}
	var live := game.surface_state(run, environment, session)
	_check(not bool(live.get("wager_blocked", true)), "Already-dealt hand is outside the new-wager shortfall guard.")
	_check(bool(live.get("can_hit", false)) and bool(live.get("can_stand", false)), "Live player decisions survive a low remaining wallet.")
	hand["stood"] = true
	var complete := game.surface_state(run, environment, session)
	_check(bool(complete.get("settle_available", false)), "A committed completed hand can still settle.")
	_check(run.bankroll == 0 and run.rng_state == rng, "Presentation checks do not transact or draw cards.")
	print("BLACKJACK_UNAFFORDABLE_WAGER " + JSON.stringify({"checks": checks, "failures": failures, "fixture": "synthetic floor/cash and live-hand presentation; production module"}))
	quit(0 if failures.is_empty() else 1)

func _card(rank: int, suit: String) -> Dictionary: return {"rank": rank, "suit": suit}
func _check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
