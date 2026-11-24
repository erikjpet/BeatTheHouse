extends SceneTree

# Controlled module-command fixtures only.
# Actual marker/payment/door/timer reproduction remains separate native evidence.
const Roulette := preload("res://scripts/games/roulette.gd")
var checks := 0
var failures: Array[String] = []
var library: ContentLibrary

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").is_absolute_path(), "Explicit isolated persistence is required."):
		_finish()
		return
	library = ContentLibrary.new()
	library.load(false)
	for fixture in [
		{"name": "repaid-cash", "cash": 12, "chips": 0, "empty": false, "resolve": false},
		{"name": "funded-cash", "cash": 112, "chips": 0, "empty": false, "resolve": true},
		{"name": "funded-chips", "cash": 0, "chips": 100, "empty": false, "resolve": true},
		{"name": "empty-sit-out", "cash": 0, "chips": 0, "empty": true, "resolve": true},
	]:
		_case(fixture)
	_finish()

func _case(fixture: Dictionary) -> void:
	var game := Roulette.new()
	game.setup(library.game("roulette"), library)
	var run := RunState.new()
	run.start_new("ROULETTE-AUTO-VALIDATION-" + str(fixture.name))
	# Declared synthetic setup funds stage the genuine module's RED command.
	run.bankroll = 112
	run.grand_casino_chips = 0
	run.simulation_msec = 1000000
	var environment := {
		"id": "roulette_auto_validation_synthetic",
		"archetype_id": "grand_casino_high_limit",
		"kind": "boss",
		"game_ids": ["roulette"],
		"economic_profile": {"stake_floor": 90, "stake_ceiling": 500},
		"security_profile": {"strictness": "high"},
	}
	var table: Dictionary = game.generate_environment_state(run, environment, run.create_rng("table"))
	table["rules"]["outside_min_each"] = 90
	table["rules"]["inside_min_total"] = 90
	table["rules"]["table_max"] = 500
	table["table_round_timer_started_msec"] = 1000000
	environment["game_states"] = {"roulette": table}
	run.current_environment = environment
	var ui := {"selected_chip": 100, "surface_time_msec": 1041001, "surface_presentation_time_msec": 1041001, "drunk_scaled_surface_time_msec": 1041001}
	if not bool(fixture.empty):
		var targets: Array = game._roulette_bet_targets(table)
		var red := -1
		for index in range(targets.size()):
			if str((targets[index] as Dictionary).get("type", "")) == "red":
				red = index
				break
		if not _check(red >= 0, str(fixture.name) + ": real RED target exists."):
			return
		var placed: Dictionary = game.surface_action_command("roulette_bet", red, false, ui, run, environment)
		ui = (placed.get("ui_state", {}) as Dictionary).duplicate(true)
		ui["surface_time_msec"] = 1041001
		ui["surface_presentation_time_msec"] = 1041001
		ui["drunk_scaled_surface_time_msec"] = 1041001
		if not _check(game._total_wager(ui.get("roulette_bets", [])) == 100, str(fixture.name) + ": module stages funded100 before declared balance change."):
			return
	# Synthetic changed balances, not a claim of a player repayment path.
	run.bankroll = int(fixture.cash)
	run.grand_casino_chips = int(fixture.chips)
	var before_cash := run.bankroll
	var before_chips := run.grand_casino_chips
	var before_rng := run.rng_state
	if not bool(fixture.resolve):
		var manual: Dictionary = game.surface_action_command("roulette_spin", 0, true, ui, run, environment)
		_check(not bool(manual.get("resolve", false)), "Manual Spin already rejects the unfunded remembered100 layout.")
	var command: Dictionary = game.surface_auto_action_command(ui, run, environment)
	_check(bool(command.get("direct_resolve", false)) == bool(fixture.resolve), str(fixture.name) + ": automatic command validates before requesting a sealed resolve.")
	_check(run.bankroll == before_cash and run.grand_casino_chips == before_chips and run.rng_state == before_rng, str(fixture.name) + ": command proposal preserves money and RNG.")
	if bool(fixture.resolve):
		_check(bool(command.get("skip_stake_validation", false)) and not bool(command.get("preserve_surface_ui_state", true)), str(fixture.name) + ": valid automatic command retains its existing host options.")
	else:
		var retained: Dictionary = command.get("ui_state", {})
		_check(game._total_wager(retained.get("roulette_bets", [])) == 100, "Rejected automatic draft remains available to edit.")
		var cleared: Dictionary = game.surface_action_command("roulette_clear", 0, false, retained, run, environment)
		_check(game._total_wager((cleared.get("ui_state", {}) as Dictionary).get("roulette_bets", [])) == 0, "Normal Clear remains available after automatic rejection.")

func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
	return ok

func _finish() -> void:
	print("ROULETTE_AUTO_LAYOUT_VALIDATION " + JSON.stringify({"checks": checks, "failures": failures, "class": "controlled synthetic module commands; no ordinary player/Web claim"}))
	quit(0 if failures.is_empty() else 1)
