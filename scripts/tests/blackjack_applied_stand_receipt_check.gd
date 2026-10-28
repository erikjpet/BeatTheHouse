extends SceneTree

# Synthetic already-confronted hand; production Deal and settlement authority.
# This does not replay a tester's accepted Stand or force/search an RNG outcome.
const Blackjack := preload("res://scripts/games/blackjack.gd")
const Driver := preload("res://scripts/tests/foundation/blackjack_authority_test_driver.gd")
const Authority := preload("res://scripts/core/blackjack_action_authority.gd")
var checks := 0
var failures: Array[String] = []
var facts := {}
var library: ContentLibrary

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	if not check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-"), "private bounded diagnostic roots required"):
		_finish(); return
	library = ContentLibrary.new()
	library.load(false)
	for available in [0, 10, 53, 80]: _case(available)
	_finish()

func _case(available: int) -> void:
	var run := RunState.new()
	run.start_new("APPLIED-STAND-RECEIPT-20261028")
	run.crew_change_reputation(0)
	run.bankroll = 78
	run.grand_casino_chips = available + 40
	run.current_environment = {"id": "applied_stand_table", "archetype_id": RunState.GRAND_CASINO_ARCHETYPE_ID, "display_name": "Synthetic penalty receipt table", "game_ids": ["blackjack"], "economic_profile": {"stake_floor": 1, "stake_ceiling": 100}, "security_profile": {}, "game_states": {}}
	run.add_suspicion("synthetic_security_precondition", 70)
	var game := Blackjack.new()
	game.setup(library.game("blackjack"), library)
	var table := game.generate_environment_state(run, run.current_environment, run.create_rng("receipt_table"))
	game.environment_state_generated(run, run.current_environment, table)
	run.current_environment.game_states["blackjack"] = table
	var environment := run.current_environment
	var deal_command := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 40, "surface_time_msec": 24000}, run, environment)
	var deal := Driver.resolve(game, "blackjack_place_bet", 40, run, environment, run.create_rng(), deal_command.get("ui_state", {}))
	if not check(bool(deal.get("ok", false)), "%d production authority accepts paid Deal" % available):
		facts[str(available)] = {"deal": deal}; return
	check(run.bankroll == 78 and run.grand_casino_chips == available, "%d Deal funds exactly40 chips" % available)
	environment = run.current_environment
	var session: Dictionary = environment.game_states.blackjack.get(Authority.LEDGER_KEY, {}).get("session", {}).duplicate(true)
	# Labelled synthetic precondition: a previously confronted off-book hand.
	# No cards/shoe/receipt/wager/RNG state are changed by this preparation.
	session["strategy_confronted"] = true
	session["cheats_used"] = {"peek_hole_card": true}
	session["peek_had_window"] = true
	session["surface_time_msec"] = 30000
	var cards: Array = session.get("player_hands", []).duplicate(true)
	var result := Driver.resolve(game, "play_basic", 53, run, environment, run.create_rng(), session)
	if not check(bool(result.get("ok", false)) and bool(result.get("blackjack_cheat_caught", false)), "%d production settlement owns already-confronted hand" % available):
		facts[str(available)] = {"result": result}; return
	var nominal := int(result.get("deltas", {}).get("chips_delta", 0))
	var applied := -mini(available, -nominal)
	check(nominal < 0 and int(result.get("deltas", {}).get("bankroll_delta", 0)) == 0, "existing routed penalty remains negative chips with no cash instruction")
	var witness := GameModule.applied_currency_settlement(result)
	check(not witness.is_empty() and int(witness.delta) == applied and int(witness.nominal_chips_delta) == nominal, "receipt distinguishes measured loss from untouched nominal penalty")
	check(run.bankroll == 78 and run.grand_casino_chips == available + applied, "existing debit/clamp arithmetic remains authoritative")
	check(int(run.narrative_flags.get("profile_bankroll_lost", 0)) == 40 - applied, "profile loss counts paid stake plus only actual settlement debit")
	var story := _last_story(run)
	check(GameModule.applied_currency_settlement(story) == witness and int(story.get("bankroll_delta", 1)) == applied and int(story.get("nominal_bankroll_delta", 0)) == nominal, "durable Stand story keeps actual and nominal separately")
	var stored: Dictionary = run.current_environment.game_states.blackjack.get("last_result", {})
	check(GameModule.applied_currency_settlement(stored) == witness and int(stored.get("bankroll_delta", 1)) == applied, "table headline uses measured chip amount")
	var before := run.to_save_snapshot()
	var repeat := GameModule.apply_result(run, result.duplicate(true))
	check(not bool(repeat.get("ok", true)) and str(repeat.get("error_code", "")) == "authority_receipt_rejected", "accepted settlement cannot be applied twice")
	check(run.to_save_snapshot() == before, "stale duplicate preserves whole run")
	var slot := "applied_stand_%d" % available
	var error := SaveService.new().save_run(run, slot)
	check(error == OK, "official private Save installs measured Stand receipt")
	var cold: Variant = SaveService.new().load_run(slot) if error == OK else null
	if check(cold is RunState, "fresh service restores measured Stand receipt"):
		check(_equal(GameModule.applied_currency_settlement(_last_story(cold)), witness), "cold story retains explicit zero/partial/full applied loss")
		check(cold.bankroll == 78 and cold.grand_casino_chips == available + applied and cold.rng_state == run.rng_state, "cold integer funds and RNG remain exact")
		check(int(cold.narrative_flags.get("profile_bankroll_lost", 0)) == 40 - applied, "cold profile retains actual loss without adding nominal again")
		var cold_before: Dictionary = cold.to_save_snapshot()
		check(not bool(GameModule.apply_result(cold, result.duplicate(true)).get("ok", true)) and cold.to_save_snapshot() == cold_before, "restored receipt rejects stale repeat without changes")
	facts[str(available)] = {"nominal": nominal, "applied": applied, "witness": witness, "cash": run.bankroll, "chips": run.grand_casino_chips, "lost": run.narrative_flags.get("profile_bankroll_lost"), "rng": str(run.rng_state), "initial_cards": cards, "story": story}

func _last_story(run: RunState) -> Dictionary:
	for index in range(run.story_log.size() - 1, -1, -1):
		var row: Dictionary = run.story_log[index]
		if str(row.get("type", "")) == "game_action" and str(row.get("action_id", "")) == "play_basic": return row
	return {}

func _equal(a: Variant, b: Variant) -> bool:
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]: return a == b
	if typeof(a) != typeof(b): return false
	if typeof(a) == TYPE_DICTIONARY:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not _equal(a[key], b[key]): return false
		return true
	if typeof(a) == TYPE_ARRAY:
		if a.size() != b.size(): return false
		for i in range(a.size()):
			if not _equal(a[i], b[i]): return false
		return true
	return a == b

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok

func _finish() -> void:
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty(): FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "facts": facts, "fidelity": "Synthetic already-confronted session, real production paid Deal and settlement authority; no search, card forcing or accepted historical action replay."}, "\t"))
	print("BLACKJACK_APPLIED_STAND checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
