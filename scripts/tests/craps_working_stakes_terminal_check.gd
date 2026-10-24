extends SceneTree

const Run := preload("res://scripts/core/run_state.gd")
const Terminal := preload("res://scripts/core/run_terminal_evaluator.gd")
const Rules := preload("res://scripts/games/craps/craps_rules.gd")
const Craps := preload("res://scripts/games/craps.gd")

var failures: Array[String] = []
var checks := 0

func _init() -> void:
	var working := {"pass_line": 5, "come": {"10": 5}, "working_on_come_out": true}
	var run := _fixture(Run.GRAND_CASINO_ARCHETYPE_ID, working)
	var rng := run.rng_state
	run.change_bankroll(-1)
	_check(not run.is_terminal(), "Spending the last liquid cash must preserve paid working wagers.")
	_check(not run.has_liquid_run_funds() and run.wager_capacity_for_game("craps", run.current_environment) == 0, "Working wagers must not become spendable funds.")
	_check(not bool(run.recovery_pressure_status().get("terminal", true)), "The recovery projection must recognize working wagers.")
	_check(not bool(Terminal.evaluate_terminal(run).get("terminal", true)), "Terminal evaluation must defer while owned wagers remain.")
	run.evaluate_immediate_terminal_state()
	_check(not run.is_terminal() and run.rng_state == rng, "Immediate checks must preserve the working wager and RNG.")
	var restored := Run.new()
	restored.from_dict(run.to_dict())
	_check(not restored.is_terminal() and restored.bankroll == 0 and restored.rng_state == rng, "Serialized zero-liquid-funds state must retain working wager recovery.")
	var cached := _fixture(Run.GRAND_CASINO_CAGE_ARCHETYPE_ID, {})
	cached.grand_casino_room_states[Run.GRAND_CASINO_ARCHETYPE_ID] = _room(Run.GRAND_CASINO_ARCHETYPE_ID, working)
	cached.change_bankroll(-1)
	_check(not cached.is_terminal(), "A free interior room transition must retain another room's working stakes.")
	_check(not bool(Terminal.evaluate_terminal(cached).get("terminal", true)), "Terminal evaluation must find cached casino wagers without needing game definitions.")
	var cached_restored := Run.new()
	cached_restored.from_dict(cached.to_dict())
	_check(not cached_restored.is_terminal(), "Cached-room working wagers must survive serialization at zero cash/chips.")
	var stale := _fixture(Run.GRAND_CASINO_ARCHETYPE_ID, {})
	stale.grand_casino_room_states[Run.GRAND_CASINO_ARCHETYPE_ID] = _room(Run.GRAND_CASINO_ARCHETYPE_ID, working)
	stale.change_bankroll(-1)
	_check(stale.is_terminal(), "An old snapshot of the active room must not resurrect already settled stakes.")
	var npc := _fixture(Run.GRAND_CASINO_ARCHETYPE_ID, {})
	npc.current_environment.game_states.craps["npc_bets"] = [{"pass_line": 100}]
	npc.current_environment.game_states.craps["last_result"] = {"craps_working_bets": working}
	npc.change_bankroll(-1)
	_check(npc.is_terminal(), "NPC bets and historical result snapshots must not keep the player solvent.")
	var staged := _fixture(Run.GRAND_CASINO_ARCHETYPE_ID, {})
	staged.current_environment.game_states.craps["craps_pending_bets"] = {"pass_line": 50}
	staged.change_bankroll(-1)
	_check(staged.is_terminal(), "Unpaid staged chips must not count as working money.")
	var outside := _fixture("bar", {})
	outside.grand_casino_room_states[Run.GRAND_CASINO_ARCHETYPE_ID] = _room(Run.GRAND_CASINO_ARCHETYPE_ID, working)
	outside.change_bankroll(-1)
	_check(outside.is_terminal(), "An inaccessible casino snapshot must not defer an outside-venue failure.")
	var loser := _fixture(Run.GRAND_CASINO_ARCHETYPE_ID, working.duplicate(true))
	loser.change_bankroll(-1)
	var lost: Dictionary = Rules.settle_roll(loser.current_environment.game_states.craps, {}, {"dice": [3, 4], "total": 7}, {})
	loser.change_bankroll(int(lost.get("bankroll_delta", 0)))
	_check(loser.is_terminal() and loser.run_failure_reason == Run.FAILURE_BANKROLL_ZERO, "Losing the final working stakes must still end a zero-money run.")
	var winner := _fixture(Run.GRAND_CASINO_ARCHETYPE_ID, working.duplicate(true))
	winner.change_bankroll(-1)
	var won: Dictionary = Rules.settle_roll(winner.current_environment.game_states.craps, {}, {"dice": [4, 4], "total": 8}, {})
	winner.change_bankroll(int(won.get("bankroll_delta", 0)))
	_check(not winner.is_terminal() and winner.bankroll > 0, "A genuine settled win must restore liquid funds.")
	var game := Craps.new()
	_check(game._working_wager_total(working) == 10, "Wager totals must count paid stakes and exclude the working-on-come-out flag.")
	print("CRAPS_WORKING_STAKES_TERMINAL_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _fixture(archetype: String, working: Dictionary) -> RunState:
	var run := Run.new()
	run.start_new("CRAPS-WORKING-STAKE-TERMINAL")
	run.current_environment = _room(archetype, working)
	run.bankroll = 1
	run.grand_casino_chips = 0
	return run

func _room(archetype: String, working: Dictionary) -> Dictionary:
	return {"id": archetype, "archetype_id": archetype, "game_states": {"craps": {"point": 8, "working_bets": working}}}

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
