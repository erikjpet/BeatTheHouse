extends SceneTree

const Game := preload("res://scripts/games/bar_dice.gd")
const Run := preload("res://scripts/core/run_state.gd")
const Host := preload("res://scripts/ui/foundation_main.gd")
const Authority := preload("res://scripts/core/blackjack_action_authority.gd")
const Codec := preload("res://scripts/core/run_save_codec.gd")

# Recreate the shipped pre-guard input sequence without weakening settlement.
class LegacyAnteGame extends Game:
	func _active_stake_from_context(stake: int, state: Dictionary, ui: Dictionary, run: RunState, env: Dictionary) -> int:
		return mini(super._active_stake_from_context(stake, state, ui, run, env), run.wager_capacity_for_game(get_id(), env))
	func _ante_block_reason(_state: Dictionary, _ui: Dictionary, _run: RunState, _env: Dictionary) -> String:
		return ""
	func sealed_action_authority_contract() -> Dictionary:
		var contract := super.sealed_action_authority_contract()
		contract["automatic_pending_recovery"] = false
		return contract

var failures: Array[String] = []
var checks := 0

func _init() -> void:
	var legacy := _pending_fixture(LegacyAnteGame.new(), 6)
	var run: RunState = legacy["run"]
	var host: Control = legacy["host"]
	var command: Dictionary = legacy["command"]
	var delivery: Dictionary = command.get("_sealed_action_host_delivery", {})
	_check(int(delivery.get("stake", 0)) == 6, "Legacy normal cup must issue the observed unauthored six-unit delivery.")
	var rng_before := run.rng_state
	var rejected: Dictionary = host.call("_sealed_action_host_resolve_intent", "roll", 6, delivery, command.get("_sealed_action_host_prepared", {}))
	_check(not bool(rejected.get("ok", true)) and run.bankroll == 6 and run.rng_state == rng_before, "Legacy rejection must retain money and RNG.")
	_check(not _ledger(run).get("pending_delivery", {}).is_empty(), "Legacy rejection must reproduce the stranded pending delivery.")
	var packed := Codec.pack_for_storage(Codec.encode(run.to_save_snapshot()))
	var restored := Run.new()
	restored.from_dict(Codec.decode(Codec.unpack_from_storage(packed.get("packed", {}))))
	_check(restored.bankroll == 6 and restored.rng_state == rng_before and not _ledger(restored).get("pending_delivery", {}).is_empty(), "Storage codec roundtrip must preserve the genuine legacy pending shape.")
	var game := Game.new()
	game.definition = (legacy["game"] as GameModule).definition
	_bind(host, game, restored)
	var fresh: Dictionary = host.call("_sealed_action_host_surface_intent", "bar_dice_stake", 0, false, 100000)
	var session: Dictionary = fresh.get("ui_state", {})
	_check(bool(fresh.get("handled", false)) and int(session.get("selected_stake_index", -1)) == 0, "Fresh chip input must recover the stranded delivery and select nine.")
	_check(str(session.get("bar_dice_ritual_phase", "")) == "agree_wager" and not bool(session.get("rolled", true)), "Unfundable uncommitted cup must return to the ante step.")
	_check(_ledger(restored).get("pending_delivery", {}).is_empty() and restored.bankroll == 6 and restored.rng_state == rng_before, "Recovery must clear only pending state without funding or RNG.")
	_check(int((game._dice_state_preview(restored, restored.current_environment)).get("rounds_played", -1)) == 0, "Recovery must not fabricate a settled round.")
	# A forged caller claim must not replace the ledger's genuine pending claim.
	var tampered := Run.new()
	tampered.from_dict(run.to_dict())
	var bad_pending: Dictionary = (_ledger(tampered).get("pending_delivery", {}) as Dictionary).duplicate(true)
	bad_pending["stake"] = 5
	var bad_host := Host.new()
	_bind(bad_host, game, tampered)
	var bad: Dictionary = bad_host.call("_sealed_action_host_resolve_intent", "roll", 5, bad_pending)
	_check(not bool(bad.get("ok", true)) and not bool(bad.get(Authority.HOST_COMMITTED_KEY, true)) and tampered.bankroll == 6 and tampered.rng_state == rng_before, "Forged pending delivery must not be accepted or funded.")
	_check(int((_ledger(tampered).get("pending_delivery", {}) as Dictionary).get("stake", 0)) == 6, "Forged caller input must not rewrite the genuine pending stake.")
	bad_host.free()
	host.free()
	# A valid interrupted pending hand keeps its dice and can settle exactly once.
	var valid := _pending_fixture(Game.new(), 100)
	var valid_run: RunState = valid["run"]
	var valid_host: Control = valid["host"]
	var valid_rng := valid_run.rng_state
	var prior_dice: Array = (_ledger(valid_run).get("session", {}) as Dictionary).get("dice", []).duplicate()
	var resumed: Dictionary = valid_host.call("_sealed_action_host_surface_intent", "bar_dice_ack_call", 0, false, 100000)
	var resumed_session: Dictionary = resumed.get("ui_state", {})
	_check(resumed_session.get("dice", []) == prior_dice and bool(resumed_session.get("rolled", false)) and valid_run.bankroll == 100 and valid_run.rng_state == valid_rng, "Valid pending recovery must preserve the exact unfunded cup without rerolling.")
	var next_delivery: Dictionary = resumed.get("_sealed_action_host_delivery", {})
	_check(not next_delivery.is_empty(), "Recovered valid cup must issue a fresh authenticated delivery.")
	if not next_delivery.is_empty():
		var result: Dictionary = valid_host.call("_sealed_action_host_resolve_intent", "roll", int(next_delivery.get("stake", 0)), next_delivery, resumed.get("_sealed_action_host_prepared", {}))
		_check(bool(result.get("ok", false)) and valid_run.bankroll == 100 + int(result.get("bankroll_delta", 0)), "Valid recovered hand must settle against its exact stake once.")
		var settled_cash := valid_run.bankroll
		var settled_rng := valid_run.rng_state
		var replay: Dictionary = valid_host.call("_sealed_action_host_resolve_intent", "roll", int(next_delivery.get("stake", 0)), next_delivery)
		_check(bool(replay.get("ok", false)) and valid_run.bankroll == settled_cash and valid_run.rng_state == settled_rng, "Recovered settlement replay must not repeat money or RNG.")
	valid_host.free()
	print("BAR_DICE_PENDING_RECOVERY_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _pending_fixture(game: BarDiceGame, cash: int) -> Dictionary:
	game.definition = {"id": "bar_dice", "family": "dice", "legal_actions": [], "cheat_actions": []}
	var run := Run.new()
	run.start_new("BAR-DICE-PENDING-RECOVERY")
	run.bankroll = cash
	var env := {"id": "bar_dice_pending_fixture", "archetype_id": "street_register", "economic_profile": {"stake_floor": 9, "stake_ceiling": 25}, "game_states": {}}
	var table := game.generate_environment_state(run, env, run.create_rng("pending_table"))
	table["stake_ladder"] = [9, 10, 25]
	table["selected_stake_index"] = 1
	env["game_states"] = {"bar_dice": table}
	run.current_environment = env
	var host := Host.new()
	_bind(host, game, run)
	var command: Dictionary = {}
	for action in ["bar_dice_roll", "bar_dice_ack_cover", "bar_dice_resolve", "bar_dice_throw", "bar_dice_reveal", "bar_dice_ack_call"]:
		command = host.call("_sealed_action_host_surface_intent", action, 0, false, 100000)
	return {"game": game, "run": run, "host": host, "command": command}

func _bind(host: Control, game: BarDiceGame, run: RunState) -> void:
	host.set("current_game", game)
	host.set("game_module_cache", {"bar_dice": game})
	host.set("action_authority_contract", game.sealed_action_authority_contract())
	host.set("run_state", run)
	host.set("selected_stake", 10)

func _ledger(run: RunState) -> Dictionary:
	return (run.current_environment.get("game_states", {}) as Dictionary).get("bar_dice", {}).get(Authority.LEDGER_KEY, {})

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
