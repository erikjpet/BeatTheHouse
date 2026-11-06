extends SceneTree

# BTH061-BAR-DICE-REVEAL-RESTORE-001: focused synthetic contract unit.
# A normal sealed Host accepts a six-unit cup at floor6. Changing only this
# unit's current floor to10 models venue terms changing after acceptance; it is
# not normal travel, a natural-clock reproduction or an original player save.
# No disk services, financial resolution, scenario edits or outcome selection.
# Full MainScene save/cold-load/funding/replay acceptance is a separate check.
const Game := preload("res://scripts/games/bar_dice.gd")
const Run := preload("res://scripts/core/run_state.gd")
const Host := preload("res://scripts/ui/foundation_main.gd")
const Authority := preload("res://scripts/core/blackjack_action_authority.gd")
const AGREED_ANTE := "bar_dice_agreed_ante"

var checks: int = 0
var failures: Array[String] = []
var input_msec: int = 100000


func _init() -> void:
	var fixture: Dictionary = _fixture(6)
	var game: BarDiceGame = fixture["game"]
	var run: RunState = fixture["run"]
	var host: Control = fixture["host"]
	var initial_rng: int = run.rng_state
	_surface(host, "bar_dice_stake", 0)
	_surface(host, "bar_dice_roll")
	_check_phase_and_restore(game, run, "cover", initial_rng)
	_surface(host, "bar_dice_ack_cover")
	_check_phase_and_restore(game, run, "shake", initial_rng)
	_surface(host, "bar_dice_shake")
	_surface(host, "bar_dice_shake")
	_check(int(_session(run).get("shake_number", 0)) == 3, "Two remaining normal shakes retain the same accepted cup.")
	_surface(host, "bar_dice_resolve")
	_check_phase_and_restore(game, run, "throw", initial_rng)
	_surface(host, "bar_dice_throw")
	_check_phase_and_restore(game, run, "reveal", initial_rng)
	var accepted_snapshot: Dictionary = run.to_dict()
	var accepted_ui: Dictionary = _session(run).duplicate(true)
	_check(run.bankroll == 94 and run.rng_state == initial_rng and _ledger(run).get("pending_delivery", {}).is_empty() and _ledger(run).get("request_order", []).is_empty(), "Staging through Reveal adds no debit, root-RNG draw, pending delivery or settlement receipt.")

	# A newly selected six has no accepted-cup exemption at the new floor.
	var fresh: Dictionary = _fixture(10)
	var fresh_game: BarDiceGame = fresh["game"]
	var fresh_run: RunState = fresh["run"]
	var fresh_host: Control = fresh["host"]
	_surface(fresh_host, "bar_dice_stake", 0)
	_surface(fresh_host, "bar_dice_roll")
	_check(str(_session(fresh_run).get("bar_dice_ritual_phase", "")) == "agree_wager" and not _session(fresh_run).has(AGREED_ANTE) and fresh_game._sealed_bar_dice_stake(6, _table(fresh_run), _session(fresh_run), fresh_run, fresh_run.current_environment) == 0, "A fresh six-unit wager at floor10 remains rejected before Cover.")
	_surface(fresh_host, "bar_dice_stake", 1)
	_surface(fresh_host, "bar_dice_roll")
	_check(str(_session(fresh_run).get("bar_dice_ritual_phase", "")) == "cover" and int(_session(fresh_run).get(AGREED_ANTE, 0)) == 10 and fresh_game._bar_dice_wager_cost_candidate("roll", 10, fresh_run, _session(fresh_run)) == 10 and fresh_run.bankroll == 94, "A fresh authored ten-unit wager at floor10 is accepted without early funding.")
	fresh_host.free()

	# Caller UI alone never supplies acceptance provenance, even with valid dice.
	var invented: Dictionary = _fixture(10)
	var invented_game: BarDiceGame = invented["game"]
	var invented_run: RunState = invented["run"]
	var invented_host: Control = invented["host"]
	var fake_ui: Dictionary = accepted_ui.duplicate(true)
	fake_ui[AGREED_ANTE] = 6
	_check(_ledger(invented_run).is_empty() and invented_game._sealed_bar_dice_stake(6, _table(invented_run), fake_ui, invented_run, invented_run.current_environment) == 0 and not invented_game._ante_block_reason(_table(invented_run), fake_ui, invented_run, invented_run.current_environment).is_empty() and invented_game.restored_surface_ui_state(invented_run, invented_run.current_environment).is_empty(), "Caller rolled/agreed-ante claims without a canonical ledger cannot bypass floor10.")
	var borrowed_environment: Dictionary = accepted_snapshot.current_environment.duplicate(true)
	borrowed_environment.economic_profile.stake_floor = 10
	_check(invented_game._sealed_bar_dice_stake(6, _table(invented_run), fake_ui, invented_run, borrowed_environment) == 0, "A borrowed environment ledger cannot replace the actual run's canonical cup.")
	invented_host.free()

	for invalid_kind: String in ["binding", "version", "present_zero"]:
		var invalid_run: RunState = _restored_at_floor(accepted_snapshot, 10)
		var invalid_ledger: Dictionary = _ledger(invalid_run)
		match invalid_kind:
			"binding": invalid_ledger["table_binding"] = "bar_dice:wrong_fixture:bar"
			"version": invalid_ledger["version"] = int(invalid_ledger.get("version", 0)) + 1
			"present_zero": (invalid_ledger["session"] as Dictionary)[AGREED_ANTE] = 0
		_check(game.restored_surface_ui_state(invalid_run, invalid_run.current_environment).is_empty() and game._sealed_bar_dice_stake(6, _table(invalid_run), accepted_ui, invalid_run, invalid_run.current_environment) == 0, "Invalid canonical " + invalid_kind + " cannot fall back to legacy accepted terms.")

	# Legacy acceptance comes only from the validated canonical in-progress cup.
	var legacy_run: RunState = _restored_at_floor(accepted_snapshot, 10)
	(_ledger(legacy_run)["session"] as Dictionary).erase(AGREED_ANTE)
	var legacy_ui: Dictionary = game.restored_surface_ui_state(legacy_run, legacy_run.current_environment)
	_check(str(legacy_ui.get("bar_dice_ritual_phase", "")) == "reveal" and legacy_ui.get("dice", []) == accepted_ui.get("dice", []) and game._bar_dice_wager_cost_candidate("roll", 6, legacy_run, legacy_ui) == 6 and legacy_run.bankroll == 94, "A valid legacy canonical cup without the new field retains exact dice and its six-unit cost.")

	# Accepted terms do not make an unfunded cup affordable after a wallet change.
	var poor_run: RunState = _restored_at_floor(accepted_snapshot, 10)
	poor_run.bankroll = 5
	var poor_ui: Dictionary = _session(poor_run).duplicate(true)
	_check(game.restored_surface_ui_state(poor_run, poor_run.current_environment).is_empty() and not game._ante_block_reason(_table(poor_run), poor_ui, poor_run, poor_run.current_environment).is_empty(), "Five available cash still rejects restoration of an unfunded six-unit cup.")
	game._bar_dice_restore_recovery_session(poor_run, poor_ui)
	_check(not bool(poor_ui.get("rolled", true)) and str(poor_ui.get("bar_dice_ritual_phase", "")) == "agree_wager" and not poor_ui.has(AGREED_ANTE) and not poor_ui.has("dice") and poor_run.bankroll == 5, "Unfundable recovery clears accepted ante and cup only, without funding or refund.")

	# The accepted-ante feature must not weaken cold checkpoint reconciliation.
	var tampered: Dictionary = accepted_snapshot.duplicate(true)
	var tampered_environment: Dictionary = tampered["current_environment"]
	var tampered_states: Dictionary = tampered_environment["game_states"]
	var tampered_table: Dictionary = tampered_states["bar_dice"]
	var tampered_ledger: Dictionary = tampered_table[Authority.LEDGER_KEY]
	tampered_ledger["checkpoint_fingerprint"] = "0".repeat(64)
	var cold: RunState = Run.new()
	cold.from_dict(tampered)
	_check(_ledger(cold).is_empty() and game.restored_surface_ui_state(cold, cold.current_environment).is_empty() and cold.bankroll == 94 and cold.rng_state == initial_rng, "Cold restore still strips a checkpoint-tampered ledger and preserves the account/root RNG.")
	host.free()
	print("BAR_DICE_ACCEPTED_ANTE_RESULT " + JSON.stringify({"checks": checks, "failures": failures, "scope": "Synthetic module/sealed-host contract; controlled current floor6-to10; no economic resolution, disk save or original-state access"}))
	quit(0 if failures.is_empty() else 1)


func _fixture(floor_value: int) -> Dictionary:
	var game: BarDiceGame = Game.new()
	game.definition = {"id": "bar_dice", "family": "dice", "legal_actions": [], "cheat_actions": []}
	var run: RunState = Run.new()
	run.start_new("BTH061-BAR-DICE-ACCEPTED-ANTE-UNIT-A")
	run.bankroll = 94
	var environment: Dictionary = {"id": "accepted_ante_unit", "archetype_id": "bar", "economic_profile": {"stake_floor": floor_value, "stake_ceiling": 20}, "game_states": {}}
	var table: Dictionary = game.generate_environment_state(run, environment, run.create_rng("accepted_ante_unit_table"))
	table["stake_ladder"] = [6, 10, 20]
	table["selected_stake_index"] = 0
	environment["game_states"] = {"bar_dice": table}
	run.current_environment = environment
	var host: Control = Host.new()
	host.set("run_state", run)
	host.set("current_game", game)
	host.set("game_module_cache", {"bar_dice": game})
	host.set("action_authority_contract", game.sealed_action_authority_contract())
	host.set("selected_stake", 6)
	return {"game": game, "run": run, "host": host}


func _surface(host: Control, action: String, index: int = 0) -> void:
	input_msec += 1000
	host.call("_sealed_action_host_surface_intent", action, index, false, input_msec)


func _check_phase_and_restore(game: BarDiceGame, run: RunState, phase: String, original_rng: int) -> void:
	var canonical: Dictionary = _session(run)
	_check(str(canonical.get("bar_dice_ritual_phase", "")) == phase and int(canonical.get(AGREED_ANTE, 0)) == 6, "Normal Host " + phase + " retains canonical accepted six-unit ante.")
	var restored: RunState = _restored_at_floor(run.to_dict(), 10)
	var ui: Dictionary = game.restored_surface_ui_state(restored, restored.current_environment)
	_check(str(ui.get("bar_dice_ritual_phase", "")) == phase and ui.get("dice", []) == canonical.get("dice", []) and game._active_stake_from_context(0, _table(restored), ui, restored, restored.current_environment) == 6 and game._bar_dice_wager_cost_candidate("roll", 6, restored, ui) == 6 and restored.bankroll == 94 and restored.rng_state == original_rng, "Controlled floor10 " + phase + " restoration keeps exact dice, six-unit cost and unchanged account/root RNG.")


func _restored_at_floor(snapshot: Dictionary, floor_value: int) -> RunState:
	var run: RunState = Run.new()
	run.from_dict(snapshot.duplicate(true))
	# Explicit contract-unit term mutation; no production scenario/time boundary.
	var economic_profile: Dictionary = run.current_environment.get("economic_profile", {})
	economic_profile["stake_floor"] = floor_value
	run.current_environment["economic_profile"] = economic_profile
	return run


func _table(run: RunState) -> Dictionary:
	var states: Dictionary = run.current_environment.get("game_states", {})
	return states.get("bar_dice", {})


func _ledger(run: RunState) -> Dictionary:
	return _table(run).get(Authority.LEDGER_KEY, {})


func _session(run: RunState) -> Dictionary:
	return _ledger(run).get("session", {})


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
