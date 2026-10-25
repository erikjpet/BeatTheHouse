extends SceneTree

const Game := preload("res://scripts/games/bar_dice.gd")
const Run := preload("res://scripts/core/run_state.gd")
const Host := preload("res://scripts/ui/foundation_main.gd")
const Authority := preload("res://scripts/core/blackjack_action_authority.gd")

var failures: Array[String] = []
var checks := 0

func _init() -> void:
	var game := Game.new()
	game.definition = {"id": "bar_dice", "family": "dice", "legal_actions": [], "cheat_actions": []}
	var run := Run.new()
	run.start_new("BAR-DICE-UNAFFORDABLE-ANTE")
	run.bankroll = 6
	var environment := {"id": "bar_dice_ante_fixture", "archetype_id": "street_register", "economic_profile": {"stake_floor": 9, "stake_ceiling": 25}, "game_states": {}}
	var table := game.generate_environment_state(run, environment, run.create_rng("ante_table"))
	table["stake_ladder"] = [9, 10, 25]
	table["selected_stake_index"] = 1
	environment["game_states"] = {"bar_dice": table}
	run.current_environment = environment
	var ui := {"selected_stake_index": 1, "bar_dice_ritual_phase": "agree_wager"}
	var before_rng := run.rng_state
	var view := game.surface_state(run, environment, ui)
	_check(int(view.get("active_stake", 0)) == 10, "Displayed ante must remain the selected authored chip, never a clamped six.")
	_check((view.get("stake_ladder", []) as Array).has(view.get("active_stake")), "Displayed ante must belong to the authored ladder.")
	_check(str(view.get("ante_block_reason", "")).contains("9"), "Below-table funds must explain the minimum needed.")
	_check(game._bar_dice_console_prompt(view, "bet", {}).contains("9"), "The visible console must show the minimum rather than inviting an impossible hand.")
	for action in ["bar_dice_roll", "bar_dice_resolve"]:
		_check(not _button_enabled(view, action), "Unaffordable step play and autoplay must be disabled: " + action)
		var command := game.surface_action_command(action, 0, false, ui, run, environment)
		_check(str((command.get("ui_state", {}) as Dictionary).get("bar_dice_ritual_phase", "")) == "agree_wager" and not bool(command.get("resolve", false)), "Direct unaffordable starts must stay before cover: " + action)
	_check(run.bankroll == 6 and run.rng_state == before_rng and int(table.get("rounds_played", 0)) == 0, "Blocked starts and surface refresh must preserve money, RNG and round count.")
	_check(game._sealed_bar_dice_stake(6, table, ui, run, environment) == 0, "Authority must continue rejecting unauthored six-unit stakes.")
	# A smaller authored chip remains selectable when only the default is too high.
	run.bankroll = 9
	view = game.surface_state(run, environment, ui)
	_check(int(view.get("active_stake", 0)) == 10 and not _button_enabled(view, "bar_dice_roll"), "Nine funds must not silently change the selected ten to nine.")
	var smaller := game.surface_action_command("bar_dice_stake", 0, false, ui, run, environment)
	var smaller_ui: Dictionary = smaller.get("ui_state", {})
	view = game.surface_state(run, environment, smaller_ui)
	_check(int(view.get("active_stake", 0)) == 9 and _button_enabled(view, "bar_dice_roll"), "Fresh selection of an affordable authored chip must enable play.")
	var start := game.surface_action_command("bar_dice_roll", 0, false, smaller_ui, run, environment)
	_check(str((start.get("ui_state", {}) as Dictionary).get("bar_dice_ritual_phase", "")) == "cover", "Affordable exact-balance step play must reach cover.")
	_check(game._sealed_bar_dice_stake(9, table, smaller_ui, run, environment) == 9, "Authority must retain an exact authored affordable stake.")
	# Existing sealed host, valid exact stake and replay accounting remain authoritative.
	run.bankroll = 100
	var host := Host.new()
	host.current_game = game
	host.game_module_cache = {"bar_dice": game}
	host.run_state = run
	host.selected_stake = 10
	var result: Dictionary = host._sealed_action_host_resolve_intent("roll", 10)
	_check(bool(result.get("ok", false)) and bool(result.get(Authority.HOST_COMMITTED_KEY, false)), "An authored affordable ten-unit wager must still commit.")
	_check(int(result.get("stake", 0)) == 10 and run.bankroll == 100 + int(result.get("bankroll_delta", 0)), "Valid settlement must retain the exact stake and accounting basis.")
	var settled_cash := run.bankroll
	var settled_rng := run.rng_state
	var replay: Dictionary = host._sealed_action_host_resolve_intent("roll", 10, result.get(Authority.HOST_DELIVERY_KEY, {}))
	_check(bool(replay.get("ok", false)) and run.bankroll == settled_cash and run.rng_state == settled_rng, "Delivery replay must not repeat money or RNG.")
	host.free()
	print("BAR_DICE_UNAFFORDABLE_ANTE_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _button_enabled(view: Dictionary, action: String) -> bool:
	for button in view.get("bar_dice_action_buttons", []):
		if str((button as Dictionary).get("action", "")) == action:
			return bool((button as Dictionary).get("enabled", false))
	return false

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
