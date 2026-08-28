extends "res://scripts/tests/foundation/check_slots_surfaces.gd"

const CrapsRulesScript := preload("res://scripts/games/craps/craps_rules.gd")
const GameRitualRuntimeContractScript := preload("res://scripts/tests/foundation/game_ritual_runtime_contract.gd")


func _check_all_game_module_contracts(library: ContentLibrary, failures: Array) -> void:
	super._check_all_game_module_contracts(library, failures)
	GameRitualRuntimeContractScript.check(library, failures)


func _check_craps_surface_contract(game: GameModule, failures: Array, library: ContentLibrary = null) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("CRAPS-SURFACE-CONTRACT")
	run_state.bankroll = 100000
	var environment := _surface_contract_environment()
	environment["archetype_id"] = RunState.GRAND_CASINO_ARCHETYPE_ID
	environment["id"] = "grand_casino_craps_contract"
	environment["kind"] = "boss"
	environment["game_ids"] = ["craps"]
	environment["music_profile"] = {"volume": 0.25, "ambience": 0.40, "bpm": 82.0}
	var table := game.generate_environment_state(run_state, environment, run_state.create_rng("craps_contract_table"))
	if str(table.get("schema", "")) != "craps_table_state":
		failures.append("Craps generated table state did not expose the craps schema.")
		return
	for key in ["point", "working_bets", "roll_history", "hot_shooter_streak", "table_energy", "rules"]:
		if not table.has(key):
			failures.append("Craps generated table state is missing %s." % key)
	environment["game_states"] = {"craps": table}
	run_state.set_environment(environment)
	run_state.grand_casino_chips = 10000
	environment = run_state.current_environment
	var surface := game.surface_state(run_state, environment, {})
	if str(surface.get("surface_renderer", "")) != "craps":
		failures.append("Craps surface did not route to its module-owned renderer.")
	_check_idle_animation_liveness_contract(surface, "Craps betting surface", failures)
	if not bool(surface.get("surface_controls_native", false)) or not bool(surface.get("surface_animates_idle", false)):
		failures.append("Craps surface did not expose native controls and idle liveness.")
	if bool(surface.get("surface_realtime_state_refresh", false)):
		failures.append("Craps idle betting surface requested full per-frame snapshot rebuilds.")
	for target_id in ["pass_line", "dont_pass", "field", "place_4", "place_5", "place_6", "place_8", "place_9", "place_10"]:
		if _craps_target_index(surface.get("bet_targets", []), target_id) < 0:
			failures.append("Craps readable betting layout is missing %s." % target_id)
	var harness := SurfaceHarness.new()
	harness.setup(surface)
	if not game.draw_surface(harness, surface, {"contract_harness": true}):
		failures.append("Craps draw_surface returned false.")
	if _surface_hit_count(harness, "craps_bet") < 9:
		failures.append("Craps renderer did not register the core readable bet targets.")
	var reduced_surface := game.surface_state(run_state, environment, {"reduce_motion": true})
	_check_craps_idle_motion(game, surface, reduced_surface, failures)
	var pass_index := _craps_target_index(surface.get("bet_targets", []), "pass_line")
	var bet_command := game.surface_action_command("craps_bet", pass_index, false, {"selected_chip": 5}, run_state, environment)
	var bet_ui: Dictionary = bet_command.get("ui_state", {})
	if int(_craps_dict(bet_ui.get("craps_pending_bets", {})).get("pass_line", 0)) != 5:
		failures.append("Craps Pass Line placement did not stage exactly one selected chip.")
	if game.wager_cost_for_context("roll_craps", 0, run_state, environment, bet_ui) != 5:
		failures.append("Craps wager cost did not reflect newly staged bets only.")
	var roll_command := game.surface_action_command("craps_roll", 0, false, bet_ui, run_state, environment)
	if not bool(roll_command.get("resolve", false)) or str(roll_command.get("action_id", "")) != "roll_craps":
		failures.append("Craps Roll did not resolve through the normal legal action boundary.")

	_check_craps_rule_matrix(game, table, failures)
	_check_craps_save_restore(game, run_state, environment, failures)
	_check_craps_deterministic_surface_clock(game, failures)
	_check_craps_cheat_contract(game, failures)
	_check_craps_luck_contract(game, failures)
	_check_craps_energy_projection(game, table, failures)
	_check_craps_street_variant(game, library, failures)
	_check_craps_casino_activation_invariant(game, failures)
	_check_craps_currency_routing(failures)
	if library != null:
		_check_craps_room_registration_and_duel(game, library, failures)


func _check_craps_street_variant(game: GameModule, library: ContentLibrary, failures: Array) -> void:
	if library == null:
		failures.append("Street Craps contract requires the content library.")
		return
	var scenario := library.scenario("back_alley_street_craps")
	var mutations := _craps_dict(scenario.get("mutations", {}))
	var modifiers := _craps_dict(mutations.get("game_modifier_hooks", {}))
	var opportunity := _craps_dict(mutations.get("exclusive_opportunity", {}))
	if str(modifiers.get("game_hook", "")) != "street_craps" or str(opportunity.get("game_id", "")) != "craps":
		failures.append("Street Craps scenario does not activate the shared Craps module through its shipped hook and exclusive-opportunity seam.")
	var cruiser := library.scenario("back_alley_cruiser_parked")
	if str(_craps_dict(_craps_dict(cruiser.get("mutations", {})).get("game_modifier_hooks", {})).get("game_hook", "")) == "street_craps":
		failures.append("Cruiser Parked and Street Craps lost their single-scenario exclusivity boundary.")

	var run_state: RunState = RunStateScript.new()
	run_state.start_new("STREET-CRAPS-CONTRACT")
	run_state.bankroll = 100
	run_state.grand_casino_chips = 50
	var environment := _street_craps_environment()
	var table := game.generate_environment_state(run_state, environment, run_state.create_rng("street_craps_table"))
	if str(table.get("variant_id", "")) != "street_craps" or int(table.get("table_minimum", 0)) != 2 or int(table.get("table_maximum", 0)) != 20:
		failures.append("Street Craps did not generate its data-authored gutter-stake variant.")
	if JSON.stringify(table.get("rules", {})) != JSON.stringify(_craps_dict(game.definition.get("craps_config", {})).get("rules", {})):
		failures.append("Street Craps forked the core rules dictionary instead of reusing it exactly.")
	environment["game_states"] = {"craps": table}
	run_state.current_environment = environment
	var round_tripped_value: Variant = JSON.parse_string(JSON.stringify(run_state.to_dict()))
	if typeof(round_tripped_value) != TYPE_DICTIONARY:
		failures.append("Street Craps contract could not JSON-round-trip its RunState fixture.")
		return
	var restored_run_state: RunState = RunStateScript.new()
	restored_run_state.from_dict(round_tripped_value as Dictionary)
	run_state = restored_run_state
	var before_enter := JSON.stringify(run_state.to_dict())
	var first_enter := game.enter(run_state, run_state.current_environment)
	var after_enter := JSON.stringify(run_state.to_dict())
	if before_enter != after_enter or bool(run_state.narrative_flags.get("street_craps_guidance_seen", false)):
		failures.append("Street Craps info-card selection mutated a JSON-round-tripped serialized RunState before an action boundary.")
	_check_craps_open_then_play_determinism(game, run_state, {"craps_pending_bets": {"pass_line": 2}}, 2, "Street Craps", failures)
	var surface := game.surface_state(run_state, run_state.current_environment, {})
	var target_ids: Array = []
	for target_value in _craps_array(surface.get("bet_targets", [])):
		if typeof(target_value) == TYPE_DICTIONARY:
			target_ids.append(str((target_value as Dictionary).get("id", "")))
	if target_ids != ["pass_line", "dont_pass"] or str(surface.get("surface_cast", "")) != "circle_of_players" or str(surface.get("currency", "")) != "cash":
		failures.append("Street Craps surface is not the cash-only, Pass/Don't Pass circle presentation.")
	var invalid := game.resolve_with_context("roll_craps", 2, run_state, run_state.current_environment, run_state.create_rng("street_invalid"), {"craps_pending_bets": {"field": 2}})
	if bool(invalid.get("ok", false)) or bool(run_state.narrative_flags.get("street_craps_guidance_seen", false)):
		failures.append("Street Craps accepted a Field wager outside its two-line surface or consumed guidance before a successful action.")
	var before_chips := run_state.grand_casino_chips
	var cash_result := game.resolve_with_context("roll_craps", 2, run_state, run_state.current_environment, run_state.create_rng("street_cash"), {"craps_pending_bets": {"pass_line": 2}})
	if not bool(cash_result.get("ok", false)) or str(cash_result.get("currency", "")) != "cash" or run_state.grand_casino_chips != before_chips:
		failures.append("Street Craps did not route its real wager through cash while leaving casino chips untouched.")
	var second_enter := game.enter(run_state, run_state.current_environment)
	if not bool(run_state.narrative_flags.get("street_craps_guidance_seen", false)) or str(first_enter.get("message", "")) == str(second_enter.get("message", "")):
		failures.append("Street Craps did not retire its first-session diegetic guidance after the first successful action.")
	if not bool(game.surface_state(run_state, run_state.current_environment, {}).get("craps_setting_available", false)):
		failures.append("Street Craps retained the casino practice gate at gutter stakes.")
	var street_cheats := game.cheat_actions(run_state, run_state.current_environment)
	if street_cheats.size() != 1 or str(_craps_dict(street_cheats[0]).get("id", "")) != "dice_setting":
		failures.append("Street Craps exposed a cheat action other than its shared dice-setting window.")

	_check_street_craps_disperse(game, failures)
	_check_street_craps_training(game, failures)
	_check_street_craps_save_restore(game, failures)
	var core_environment := _surface_contract_environment()
	var core_table := game.generate_environment_state(run_state, core_environment, run_state.create_rng("street_trace_isolation"))
	var core_surface := game.surface_state(run_state, core_environment, {})
	if core_table.has("variant_id") or core_surface.has("craps_variant"):
		failures.append("An environment without Street Craps retained variant traces.")


func _check_craps_casino_activation_invariant(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("CASINO-CRAPS-ACTIVATION-INVARIANT")
	run_state.bankroll = 100
	run_state.grand_casino_chips = 100
	var environment := _surface_contract_environment()
	environment["id"] = "grand_casino_craps_activation"
	environment["archetype_id"] = RunState.GRAND_CASINO_ARCHETYPE_ID
	environment["kind"] = "boss"
	environment["game_ids"] = ["craps"]
	var table := game.generate_environment_state(run_state, environment, run_state.create_rng("casino_craps_activation_table"))
	environment["game_states"] = {"craps": table}
	run_state.set_environment(environment)
	var parsed: Variant = JSON.parse_string(JSON.stringify(run_state.to_dict()))
	if typeof(parsed) != TYPE_DICTIONARY:
		failures.append("Grand Casino Craps activation contract could not JSON-round-trip its RunState fixture.")
		return
	var restored := RunStateScript.new()
	restored.from_dict(parsed as Dictionary)
	var before_enter := JSON.stringify(restored.to_dict())
	game.enter(restored, restored.current_environment)
	if before_enter != JSON.stringify(restored.to_dict()):
		failures.append("Grand Casino Craps info-card selection mutated serialized RunState before an action boundary.")
	var minimum := int(table.get("table_minimum", 1))
	_check_craps_open_then_play_determinism(game, restored, {"craps_pending_bets": {"pass_line": minimum}}, minimum, "Grand Casino Craps", failures)


func _check_craps_open_then_play_determinism(game: GameModule, source: RunState, ui_state: Dictionary, stake: int, label: String, failures: Array) -> void:
	var opened := RunStateScript.new()
	opened.from_dict(source.to_dict())
	var direct := RunStateScript.new()
	direct.from_dict(source.to_dict())
	game.enter(opened, opened.current_environment)
	var opened_result := game.resolve_with_context("roll_craps", stake, opened, opened.current_environment, opened.create_rng("craps_activation_determinism"), ui_state)
	var direct_result := game.resolve_with_context("roll_craps", stake, direct, direct.current_environment, direct.create_rng("craps_activation_determinism"), ui_state)
	if JSON.stringify(opened_result) != JSON.stringify(direct_result) or JSON.stringify(opened.to_dict()) != JSON.stringify(direct.to_dict()):
		failures.append("%s open-then-play sequence diverged from the identical direct-play sequence." % label)


func _check_street_craps_disperse(game: GameModule, failures: Array) -> void:
	var sweep_a: RunState = RunStateScript.new()
	sweep_a.start_new("STREET-CRAPS-SWEEP")
	sweep_a.bankroll = 90
	var sweep_environment := _street_craps_environment()
	var sweep_modifiers := _craps_dict(sweep_environment.get("scenario_game_modifiers", {}))
	sweep_modifiers["sweep_adjacent"] = true
	sweep_environment["scenario_game_modifiers"] = sweep_modifiers
	var sweep_table := game.generate_environment_state(sweep_a, sweep_environment, sweep_a.create_rng("street_sweep_table"))
	sweep_table["point"] = 6
	sweep_table["working_bets"] = {"pass_line": 10, "dont_pass": 0, "pass_odds": 0, "come": {}, "dont_come": {}, "come_odds": {}, "place": {}}
	sweep_environment["game_states"] = {"craps": sweep_table}
	sweep_a.current_environment = sweep_environment
	var sweep_b: RunState = RunStateScript.new()
	sweep_b.from_dict(sweep_a.to_dict())
	var first := game.resolve_with_context("roll_craps", 0, sweep_a, sweep_a.current_environment, sweep_a.create_rng("street_sweep_resolve"), {})
	var second := game.resolve_with_context("roll_craps", 0, sweep_b, sweep_b.current_environment, sweep_b.create_rng("street_sweep_resolve"), {})
	if JSON.stringify(first) != JSON.stringify(second) or int(first.get("street_disperse_refund", 0)) != 10 or sweep_a.bankroll != 100:
		failures.append("Street Craps sweep-adjacent interruption was not deterministic or did not refund working cash at face value.")
	var dispersed_table := _craps_dict(_craps_dict(sweep_a.current_environment.get("game_states", {})).get("craps", {}))
	if not bool(dispersed_table.get("street_dispersed", false)) or int(_craps_dict(dispersed_table.get("working_bets", {})).get("pass_line", 0)) != 0:
		failures.append("Street Craps sweep interruption left the circle or a line wager active.")

	var heat_run: RunState = RunStateScript.new()
	heat_run.start_new("STREET-CRAPS-HEAT")
	heat_run.bankroll = 90
	var heat_environment := _street_craps_environment()
	var heat_table := game.generate_environment_state(heat_run, heat_environment, heat_run.create_rng("street_heat_table"))
	heat_table["point"] = 6
	heat_table["working_bets"] = {"pass_line": 10, "dont_pass": 0, "pass_odds": 0, "come": {}, "dont_come": {}, "come_odds": {}, "place": {}}
	heat_environment["game_states"] = {"craps": heat_table}
	heat_run.current_environment = heat_environment
	var heat_rng := _craps_rng_avoiding_totals(_craps_dict(heat_table.get("rules", {})), [6, 7])
	var heat_result := game.resolve_with_context("dice_setting", 0, heat_run, heat_run.current_environment, heat_rng, {"craps_setting_challenge": {"skill_grade": "blown", "skill_margin_msec": 999}})
	if str(heat_result.get("street_disperse_reason", "")) != "heat_spike" or int(heat_result.get("street_disperse_refund", 0)) != 10:
		failures.append("Street Craps heat-spike interruption did not refund the unresolved line deterministically.")


func _check_street_craps_training(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("STREET-CRAPS-TRAINING")
	run_state.bankroll = 100
	var environment := _street_craps_environment()
	environment["game_states"] = {"craps": game.generate_environment_state(run_state, environment, run_state.create_rng("street_training_table"))}
	run_state.current_environment = environment
	for lesson_index in range(2):
		var table := _craps_dict(_craps_dict(run_state.current_environment.get("game_states", {})).get("craps", {}))
		table["point"] = 0
		table["working_bets"] = {"pass_line": 0, "dont_pass": 0, "pass_odds": 0, "come": {}, "dont_come": {}, "come_odds": {}, "place": {}}
		var states := _craps_dict(run_state.current_environment.get("game_states", {}))
		states["craps"] = table
		run_state.current_environment["game_states"] = states
		var lesson_rng := _craps_rng_for_total(_craps_dict(table.get("rules", {})), 7)
		game.resolve_with_context("roll_craps", 2, run_state, run_state.current_environment, lesson_rng, {"craps_pending_bets": {"pass_line": 2}})
	if int(run_state.narrative_flags.get("craps_setting_street_progress", 0)) != 2 or not bool(run_state.narrative_flags.get("craps_setting_trained", false)):
		failures.append("Completed Street Craps line sessions did not grant the authored shared setting-training flag.")
	var casino_environment := _surface_contract_environment()
	casino_environment["game_states"] = {"craps": game.generate_environment_state(run_state, casino_environment, run_state.create_rng("street_training_casino"))}
	if not bool(game.surface_state(run_state, casino_environment, {}).get("craps_setting_available", false)):
		failures.append("Casino dice setting did not honor training earned through Street Craps.")
	var rig_run: RunState = RunStateScript.new()
	rig_run.start_new("CRAPS-PRACTICE-RIG-COMPAT")
	rig_run.narrative_flags["craps_setting_trained"] = true
	if not bool(game.surface_state(rig_run, casino_environment, {}).get("craps_setting_available", false)):
		failures.append("Casino dice setting no longer honors the shared Practice Rig training flag.")


func _check_street_craps_save_restore(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("STREET-CRAPS-SAVE")
	var environment := _street_craps_environment()
	var table := game.generate_environment_state(run_state, environment, run_state.create_rng("street_save_table"))
	table["point"] = 8
	table["working_bets"] = {"pass_line": 6, "dont_pass": 0, "pass_odds": 0, "come": {}, "dont_come": {}, "come_odds": {}, "place": {}}
	environment["game_states"] = {"craps": table}
	run_state.current_environment = environment
	var restored: RunState = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	var restored_table := _craps_dict(_craps_dict(restored.current_environment.get("game_states", {})).get("craps", {}))
	if str(restored_table.get("variant_id", "")) != "street_craps" or int(restored_table.get("point", 0)) != 8 or int(_craps_dict(restored_table.get("working_bets", {})).get("pass_line", 0)) != 6:
		failures.append("Street Craps mid-round save/load did not restore the variant, point, and unresolved cash.")


func _street_craps_environment() -> Dictionary:
	return {
		"id": "back_alley_street_craps_fixture",
		"archetype_id": "back_alley",
		"world_node_id": "back_alley",
		"kind": "shop",
		"game_ids": ["craps"],
		"economic_profile": {"stake_floor": 2, "stake_ceiling": 20},
		"scenario_id": "back_alley_street_craps",
		"scenario_game_modifiers": {"game_hook": "street_craps", "table_tone": "street"},
		"scenario_hook_flags": {"craps_onramp": true},
		"music_profile": {"volume": 0.24, "ambience": 0.72, "bpm": 82.0},
		"game_states": {},
	}


func _craps_rng_for_total(rules: Dictionary, wanted_total: int) -> RngStream:
	for seed in range(1, 1000):
		var probe := RngStream.new()
		probe.configure(seed)
		if int(CrapsRulesScript.roll_dice(probe, rules, 0).get("total", 0)) == wanted_total:
			var result := RngStream.new()
			result.configure(seed)
			return result
	var fallback := RngStream.new()
	fallback.configure(1)
	return fallback


func _craps_rng_avoiding_totals(rules: Dictionary, blocked: Array) -> RngStream:
	for seed in range(1, 1000):
		var probe := RngStream.new()
		probe.configure(seed)
		if not blocked.has(int(CrapsRulesScript.roll_dice(probe, rules, 0).get("total", 0))):
			var result := RngStream.new()
			result.configure(seed)
			return result
	var fallback := RngStream.new()
	fallback.configure(1)
	return fallback


func _check_craps_rule_matrix(game: GameModule, base_table: Dictionary, failures: Array) -> void:
	var rules := _craps_dict(base_table.get("rules", {}))
	_check_craps_authored_die_sides(failures)
	var matrix := [
		{"label": "pass natural", "point": 0, "working": {}, "pending": {"pass_line": 10}, "total": 7, "delta": 10, "point_after": 0},
		{"label": "pass craps", "point": 0, "working": {}, "pending": {"pass_line": 10}, "total": 3, "delta": -10, "point_after": 0},
		{"label": "don't pass bar", "point": 0, "working": {}, "pending": {"dont_pass": 10}, "total": 12, "delta": 0, "point_after": 0},
		{"label": "point establish", "point": 0, "working": {}, "pending": {"pass_line": 10}, "total": 6, "delta": -10, "point_after": 6},
		{"label": "point make with odds", "point": 4, "working": {"pass_line": 10, "pass_odds": 10}, "pending": {}, "total": 4, "delta": 50, "point_after": 0},
		{"label": "seven out", "point": 6, "working": {"pass_line": 10, "pass_odds": 10}, "pending": {}, "total": 7, "delta": 0, "point_after": 0},
		{"label": "don't pass point win", "point": 4, "working": {"dont_pass": 10}, "pending": {}, "total": 7, "delta": 20, "point_after": 0},
		{"label": "don't pass point loss", "point": 4, "working": {"dont_pass": 10}, "pending": {}, "total": 4, "delta": 0, "point_after": 0},
		{"label": "place six", "point": 5, "working": {"place": {"6": 6}}, "pending": {}, "total": 6, "delta": 7, "point_after": 5},
		{"label": "field twelve", "point": 6, "working": {}, "pending": {"field": 10}, "total": 12, "delta": 30, "point_after": 6},
	]
	for fixture_value in matrix:
		var fixture: Dictionary = fixture_value
		var table := _craps_rule_table(base_table, int(fixture.get("point", 0)), _craps_dict(fixture.get("working", {})))
		var settlement := CrapsRulesScript.settle_roll(table, fixture.get("pending", {}), _craps_roll(int(fixture.get("total", 0))), rules)
		if int(settlement.get("bankroll_delta", 999999)) != int(fixture.get("delta", 0)) or int(table.get("point", -1)) != int(fixture.get("point_after", 0)):
			failures.append("Craps %s fixture settled incorrectly: %s." % [str(fixture.get("label", "rules")), JSON.stringify(settlement)])
	var come_table := _craps_rule_table(base_table, 6, {})
	var come_move := CrapsRulesScript.settle_roll(come_table, {"come": 10}, _craps_roll(5), rules)
	if int(come_move.get("bankroll_delta", 0)) != -10 or int(_craps_dict(_craps_dict(come_table.get("working_bets", {})).get("come", {})).get("5", 0)) != 10:
		failures.append("Craps Come wager did not move from the apron to its rolled number.")
	var come_win := CrapsRulesScript.settle_roll(come_table, {}, _craps_roll(5), rules)
	if int(come_win.get("bankroll_delta", 0)) != 20 or _craps_dict(_craps_dict(come_table.get("working_bets", {})).get("come", {})).has("5"):
		failures.append("Craps established Come wager did not pay and clear on its number.")
	var dont_come_table := _craps_rule_table(base_table, 6, {})
	var dont_come_move := CrapsRulesScript.settle_roll(dont_come_table, {"dont_come": 10}, _craps_roll(5), rules)
	if int(dont_come_move.get("bankroll_delta", 0)) != -10 or int(_craps_dict(_craps_dict(dont_come_table.get("working_bets", {})).get("dont_come", {})).get("5", 0)) != 10:
		failures.append("Craps Don't Come wager did not move to its rolled number.")
	var dont_come_win := CrapsRulesScript.settle_roll(dont_come_table, {}, _craps_roll(7), rules)
	if int(dont_come_win.get("bankroll_delta", 0)) != 20 or _craps_dict(_craps_dict(dont_come_table.get("working_bets", {})).get("dont_come", {})).has("5"):
		failures.append("Craps established Don't Come wager did not win and clear on seven.")
	var dont_come_bar_table := _craps_rule_table(base_table, 6, {})
	var dont_come_bar := CrapsRulesScript.settle_roll(dont_come_bar_table, {"dont_come": 10}, _craps_roll(12), rules)
	if int(dont_come_bar.get("bankroll_delta", -1)) != 0 or not _craps_dict(_craps_dict(dont_come_bar_table.get("working_bets", {})).get("dont_come", {})).is_empty():
		failures.append("Craps Don't Come bar twelve did not push without moving a number.")
	var odds_off_table := _craps_rule_table(base_table, 0, {"come": {"4": 10}, "come_odds": {"4": 10}})
	var odds_off := CrapsRulesScript.settle_roll(odds_off_table, {}, _craps_roll(4), rules)
	if int(odds_off.get("bankroll_delta", 0)) != 30:
		failures.append("Craps Come odds did not return without profit while off on the come-out roll.")
	var pending_odds_win_table := _craps_rule_table(base_table, 6, {"come": {"5": 10}})
	var pending_odds_win := CrapsRulesScript.settle_roll(pending_odds_win_table, {"come_odds_5": 10}, _craps_roll(5), rules)
	if int(pending_odds_win.get("bankroll_delta", 0)) != 35 or _craps_dict(_craps_dict(pending_odds_win_table.get("working_bets", {})).get("come", {})).has("5") or _craps_dict(_craps_dict(pending_odds_win_table.get("working_bets", {})).get("come_odds", {})).has("5"):
		failures.append("Newly placed Come odds were charged but not paid and cleared on an immediate number.")
	var pending_odds_loss_table := _craps_rule_table(base_table, 6, {"come": {"5": 10}})
	var pending_odds_loss := CrapsRulesScript.settle_roll(pending_odds_loss_table, {"come_odds_5": 10}, _craps_roll(7), rules)
	if int(pending_odds_loss.get("bankroll_delta", 0)) != -10 or _craps_dict(_craps_dict(pending_odds_loss_table.get("working_bets", {})).get("come", {})).has("5") or _craps_dict(_craps_dict(pending_odds_loss_table.get("working_bets", {})).get("come_odds", {})).has("5"):
		failures.append("Newly placed Come odds were not accounted as a charged loss on immediate seven-out.")
	if CrapsRulesScript.true_odds_profit(10, 4, rules) != 20 or CrapsRulesScript.true_odds_profit(10, 5, rules) != 15 or CrapsRulesScript.true_odds_profit(10, 6, rules) != 12:
		failures.append("Craps free-odds payouts are not true odds for 4/5/6.")
	var place_table := _craps_rule_table(base_table, 5, {"place": {"6": 6}})
	CrapsRulesScript.settle_roll(place_table, {}, _craps_roll(7), rules)
	if not _craps_dict(_craps_dict(place_table.get("working_bets", {})).get("place", {})).is_empty():
		failures.append("Craps Place wager did not clear on a point-on seven-out.")
	var off_place_table := _craps_rule_table(base_table, 0, {"place": {"6": 6}})
	var off_place := CrapsRulesScript.settle_roll(off_place_table, {}, _craps_roll(6), rules)
	if int(off_place.get("bankroll_delta", -1)) != 0 or int(_craps_dict(_craps_dict(off_place_table.get("working_bets", {})).get("place", {})).get("6", 0)) != 6:
		failures.append("Craps Place wager did not remain off and working through a come-out roll.")
	var minimum := int(base_table.get("table_minimum", 1))
	var maximum := int(base_table.get("table_maximum", minimum))
	if bool(CrapsRulesScript.can_place_bet("pass_line", minimum - 1, base_table, {}, rules).get("ok", false)):
		failures.append("Craps accepted a wager below the posted table minimum.")
	if bool(CrapsRulesScript.can_place_bet("pass_line", maximum + 1, base_table, {}, rules).get("ok", false)):
		failures.append("Craps accepted a wager above the posted table maximum.")
	_check_craps_traveled_come_validation(game, base_table, failures)


func _check_craps_traveled_come_validation(game: GameModule, base_table: Dictionary, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("CRAPS-TRAVELED-COME-VALIDATION")
	run_state.bankroll = 1000
	var environment := _surface_contract_environment()
	environment["id"] = "craps_traveled_come_validation"
	environment["game_ids"] = ["craps"]
	var table := _craps_rule_table(base_table, 6, {"come": {"5": 10}, "dont_come": {"9": 10}})
	environment["game_states"] = {"craps": table}
	run_state.current_environment = environment
	var resolution_rng := RngStream.new()
	resolution_rng.configure(2)
	var result := game.resolve_with_context(
		"roll_craps",
		20,
		run_state,
		run_state.current_environment,
		resolution_rng,
		{"craps_pending_bets": {"come": 10, "dont_come": 10}}
	)
	var working := _craps_dict(result.get("craps_working_bets", {}))
	var traveled_come := _craps_dict(working.get("come", {}))
	var traveled_dont_come := _craps_dict(working.get("dont_come", {}))
	if not bool(result.get("ok", false)) or int(_craps_dict(result.get("craps_roll", {})).get("total", 0)) != 4:
		failures.append("Craps real resolve path rejected new Come wagers beside traveled-number maps.")
	elif int(traveled_come.get("5", 0)) != 10 or int(traveled_come.get("4", 0)) != 10 \
			or int(traveled_dont_come.get("9", 0)) != 10 or int(traveled_dont_come.get("4", 0)) != 10:
		failures.append("Craps real resolve path did not preserve traveled Come maps while moving new apron wagers.")


func _check_craps_authored_die_sides(failures: Array) -> void:
	var two_sided_rules := {"die_sides": 2, "seven_total": 7}
	var rng_a := RngStream.new()
	var rng_b := RngStream.new()
	rng_a.configure(60612)
	rng_b.configure(60612)
	var sequence_a: Array = []
	var sequence_b: Array = []
	var saw_authored_max := false
	for _roll_index in range(64):
		var roll_a := CrapsRulesScript.roll_dice(rng_a, two_sided_rules, 0)
		var roll_b := CrapsRulesScript.roll_dice(rng_b, two_sided_rules, 0)
		sequence_a.append(roll_a)
		sequence_b.append(roll_b)
		for die_value in _craps_array(roll_a.get("dice", [])):
			var die := int(die_value)
			if die < 1 or die > 2:
				failures.append("Craps ignored authored non-default die_sides during a deterministic throw.")
				return
			if die == 2:
				saw_authored_max = true
	if JSON.stringify(sequence_a) != JSON.stringify(sequence_b) or not saw_authored_max:
		failures.append("Craps non-default die-sides fixture was not deterministic across identical streams.")
	var four_sided_rules := {"die_sides": 4, "seven_total": 7}
	var biased_rng := RngStream.new()
	biased_rng.configure(60614)
	for _roll_index in range(64):
		for die_value in _craps_array(CrapsRulesScript.roll_dice(biased_rng, four_sided_rules, 1000).get("dice", [])):
			if int(die_value) < 1 or int(die_value) > 4:
				failures.append("Craps setting reroll escaped authored non-default die_sides.")
				return


func _check_craps_idle_motion(game: GameModule, surface: Dictionary, reduced_surface: Dictionary, failures: Array) -> void:
	var canvas: Control = GameSurfaceCanvasScript.new()
	canvas.size = Vector2(ArtContractsScript.GAME_BOARD_SIZE)
	root.add_child(canvas)
	canvas.call("set_game_module", game)
	canvas.call("render_game_snapshot", surface)
	if canvas.has_method("reset_performance_counters"):
		canvas.call("reset_performance_counters")
	var first: Dictionary = canvas.call("debug_surface_motion_sample")
	canvas.call("debug_advance_idle_liveness", 0.5)
	var second: Dictionary = canvas.call("debug_surface_motion_sample")
	if JSON.stringify(first) == JSON.stringify(second):
		failures.append("Craps-specific brass rail marker remained visually frozen across two idle times.")
	if canvas.has_method("performance_counters"):
		var counters: Dictionary = canvas.call("performance_counters")
		if int(counters.get("full_snapshot_calls", 0)) != 0:
			failures.append("Craps visible idle motion rebuilt full snapshots instead of using the surface clock.")
	if not bool(reduced_surface.get("reduce_motion", false)):
		failures.append("Craps production surface did not propagate the reduced-motion preference.")
	canvas.call("render_game_snapshot", reduced_surface)
	var reduced_first: Dictionary = canvas.call("debug_surface_motion_sample")
	canvas.call("debug_advance_idle_liveness", 0.5)
	var reduced_second: Dictionary = canvas.call("debug_surface_motion_sample")
	if JSON.stringify(reduced_first) != JSON.stringify(reduced_second):
		failures.append("Craps idle rail motion ignored reduce-motion mode.")
	root.remove_child(canvas)
	canvas.free()


func _check_craps_save_restore(game: GameModule, run_state: RunState, environment: Dictionary, failures: Array) -> void:
	var states: Dictionary = environment.get("game_states", {})
	var table: Dictionary = states.get("craps", {})
	table["point"] = 8
	table["working_bets"] = {
		"pass_line": 25,
		"dont_pass": 0,
		"pass_odds": 50,
		"come": {"5": 10},
		"dont_come": {"9": 10},
		"come_odds": {"5": 15},
		"place": {"6": 12, "10": 10},
	}
	states["craps"] = table
	environment["game_states"] = states
	run_state.current_environment = environment
	var restored: RunState = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	var restored_table: Dictionary = _craps_dict(_craps_dict(restored.current_environment.get("game_states", {})).get("craps", {}))
	if int(restored_table.get("point", 0)) != 8 or JSON.stringify(restored_table.get("working_bets", {})) != JSON.stringify(table.get("working_bets", {})):
		failures.append("Craps mid-point save/load did not restore point, working bets, and odds exactly.")
	var restored_surface := game.surface_state(restored, restored.current_environment, {})
	if int(restored_surface.get("point", 0)) != 8 or (_craps_array(restored_surface.get("working_bet_rows", []))).size() < 6:
		failures.append("Craps restored surface did not expose the complete working layout.")


func _check_craps_deterministic_surface_clock(game: GameModule, failures: Array) -> void:
	var first: RunState = RunStateScript.new()
	first.start_new("CRAPS-SURFACE-CLOCK")
	first.simulation_msec = 26000
	var environment := _surface_contract_environment()
	environment["id"] = "craps_surface_clock_fixture"
	environment["game_ids"] = ["craps"]
	var table := game.generate_environment_state(first, environment, first.create_rng("craps_surface_clock_table"))
	table["last_roll"] = {
		"dice": [3, 4],
		"total": 7,
		"initial_total": 7,
		"setting_bias_applied": false,
		"point_before": 6,
		"point_after": 0,
		"animation_id": "craps:clock-fixture:3-4",
		"resolved_at_msec": first.simulation_time_msec(),
	}
	environment["game_states"] = {"craps": table}
	first.current_environment = environment
	var second: RunState = RunStateScript.new()
	second.from_dict(first.to_dict())
	var active_ui := {
		"surface_time_msec": first.simulation_time_msec() + 100,
		"surface_presentation_time_msec": first.simulation_time_msec() + 5000,
	}
	var first_surface := game.surface_state(first, first.current_environment, active_ui)
	var second_surface := game.surface_state(second, second.current_environment, active_ui)
	if JSON.stringify(first_surface) != JSON.stringify(second_surface):
		failures.append("Craps identical run and UI inputs produced uptime-dependent surface snapshots.")
	if int(first_surface.get("surface_time_msec", 0)) != int(active_ui["surface_time_msec"]) \
			or int(first_surface.get("surface_presentation_time_msec", 0)) != int(active_ui["surface_presentation_time_msec"]):
		failures.append("Craps surface did not propagate the authoritative pause-safe simulation and presentation clocks.")
	if str(first_surface.get("phase", "")) != "rolling":
		failures.append("Craps deterministic simulation clock did not keep the saved roll animation active.")
	var channels := _craps_array(first_surface.get("surface_animation_channels", []))
	var roll_channel := _craps_dict(channels[0]) if not channels.is_empty() else {}
	if channels.is_empty() or str(roll_channel.get("active_id", "")) != "craps:clock-fixture:3-4":
		failures.append("Craps deterministic surface clock did not expose the active roll channel.")
	elif str(roll_channel.get("clock_source", "")) != "surface" \
			or int(roll_channel.get("started_msec", 0)) != first.simulation_time_msec() \
			or int(roll_channel.get("duration_msec", 0)) <= 0:
		failures.append("Craps roll phase and finite dice channel did not share the pause-safe surface clock.")
	var expired_ui := active_ui.duplicate(true)
	expired_ui["surface_time_msec"] = first.simulation_time_msec() + int(roll_channel.get("duration_msec", 0))
	var expired_surface := game.surface_state(first, first.current_environment, expired_ui)
	var expired_channels := _craps_array(expired_surface.get("surface_animation_channels", []))
	var expired_channel := _craps_dict(expired_channels[0]) if not expired_channels.is_empty() else {}
	if str(expired_surface.get("phase", "")) != "betting" or not str(expired_channel.get("active_id", "")).is_empty():
		failures.append("Craps roll phase and finite dice channel did not expire together on the pause-safe surface clock.")


func _check_craps_cheat_contract(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("CRAPS-CHEAT-CONTRACT")
	run_state.bankroll = 100000
	run_state.grand_casino_chips = 10000
	var environment := _surface_contract_environment()
	environment["id"] = "grand_casino_craps_cheat"
	environment["archetype_id"] = RunState.GRAND_CASINO_ARCHETYPE_ID
	environment["kind"] = "boss"
	environment["security_profile"] = {"strictness": "boss", "pit_boss": {"enabled": false}}
	environment["game_ids"] = ["craps"]
	environment["game_states"] = {"craps": game.generate_environment_state(run_state, environment, run_state.create_rng("craps_cheat_table"))}
	run_state.set_environment(environment)
	run_state.add_item("weighted_keyring")
	var active_setting_ui := {"craps_pending_bets": {"pass_line": 5}, "craps_setting_challenge": {"skill_grade": "", "target_msec": 20000}, "surface_time_msec": 19500}
	if not bool(game.surface_state(run_state, run_state.current_environment, active_setting_ui).get("surface_realtime_state_refresh", false)):
		failures.append("Active Craps timing meter did not request the bounded realtime snapshot refresh it needs.")
	var setting_ui := {"craps_pending_bets": {"pass_line": 5}, "craps_setting_challenge": {"skill_grade": "perfect", "skill_margin_msec": 0}, "surface_time_msec": 20000}
	var setting := game.resolve_with_context("dice_setting", 5, run_state, run_state.current_environment, run_state.create_rng("craps_setting"), setting_ui)
	if not bool(setting.get("skill_cheat_contract", false)) or str(setting.get("skill_grade", "")) != "perfect" or int(setting.get("base_suspicion_delta", 0)) <= 0:
		failures.append("Craps dice setting did not expose the shared skill-cheat contract and security-scaled cost.")
	if bool(game.surface_state(run_state, run_state.current_environment, setting_ui).get("surface_realtime_state_refresh", false)):
		failures.append("Resolved Craps timing state kept rebuilding full snapshots after its action boundary.")
	var untrained: RunState = RunStateScript.new()
	untrained.start_new("CRAPS-SETTING-GATE")
	untrained.bankroll = 100000
	untrained.grand_casino_chips = 10000
	var untrained_environment := environment.duplicate(true)
	untrained_environment["game_states"] = {"craps": game.generate_environment_state(untrained, untrained_environment, untrained.create_rng("craps_untrained_table"))}
	untrained.set_environment(untrained_environment)
	var blocked := game.resolve_with_context("dice_setting", 5, untrained, untrained.current_environment, untrained.create_rng("craps_untrained"), setting_ui)
	if bool(blocked.get("ok", false)):
		failures.append("Craps dice setting bypassed the practice flag/item gate.")
	for item_id in ["dice_calipers", "false_bottom_cup"]:
		untrained.add_item(item_id)
	var switch_ui := {"craps_pending_bets": {"pass_line": 5}, "craps_switching_challenge": {"skill_grade": "blown", "skill_margin_msec": 999}, "surface_time_msec": 24000}
	var switching := game.resolve_with_context("dice_switching", 5, untrained, untrained.current_environment, untrained.create_rng("craps_switching"), switch_ui)
	if not bool(switching.get("skill_cheat_contract", false)) or str(switching.get("skill_outcome", "")) != "caught":
		failures.append("Craps dice switching failure did not expose a caught skill challenge.")
	if untrained.inventory.has("dice_calipers") or untrained.inventory.has("false_bottom_cup"):
		failures.append("Craps failed dice switch did not confiscate both required shipped items.")


func _check_craps_luck_contract(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("CRAPS-LUCK-CONTRACT")
	run_state.bankroll = 1000
	run_state.baseline_luck = 5
	var environment := _surface_contract_environment()
	environment["id"] = "craps_luck_fixture"
	environment["game_ids"] = ["craps"]
	var table := game.generate_environment_state(run_state, environment, run_state.create_rng("craps_luck_table"))
	environment["game_states"] = {"craps": table}
	run_state.current_environment = environment
	var rules := _craps_dict(table.get("rules", {}))
	var authored_naturals := _craps_int_array(rules.get("come_out_naturals", []))
	var natural_seed := 0
	for candidate_seed in range(1, 10000):
		var probe := RngStream.new()
		probe.configure(candidate_seed)
		var probe_roll := CrapsRulesScript.roll_dice(probe, rules, 0)
		if authored_naturals.has(int(probe_roll.get("total", 0))):
			natural_seed = candidate_seed
			break
	if natural_seed == 0:
		failures.append("Craps luck fixture could not find a deterministic authored natural.")
		return
	var resolution_rng := RngStream.new()
	resolution_rng.configure(natural_seed)
	var expected_bonus := run_state.luck_payout_bonus(10, true)
	var result := game.resolve_with_context("roll_craps", 10, run_state, run_state.current_environment, resolution_rng, {"craps_pending_bets": {"pass_line": 10}})
	var resolved_total := int(_craps_dict(result.get("craps_roll", {})).get("total", 0))
	if not authored_naturals.has(resolved_total):
		failures.append("Craps luck fixture did not replay its deterministic authored natural.")
	elif expected_bonus <= 0 or int(result.get("luck_payout_bonus", 0)) != expected_bonus:
		failures.append("Craps win did not apply RunState's exact luck_payout_bonus seam.")


func _check_craps_energy_projection(game: GameModule, base_table: Dictionary, failures: Array) -> void:
	var rules := _craps_dict(base_table.get("rules", {}))
	var table := _craps_rule_table(base_table, 4, {"pass_line": 5})
	var environment := {"music_profile": {"volume": 0.25, "ambience": 0.4, "bpm": 80.0}, "scenario_game_modifiers": {"craps_table_energy": {"energy_multiplier": 2.0, "hot_threshold": 8, "max_bpm_nudge": 12.0, "patron_lines": ["The scenario rail answers the point."]}}}
	var zero_music := JSON.stringify(environment.get("music_profile", {}))
	var zero_projection: Dictionary = game.call("_project_table_energy", environment, table)
	if not zero_projection.is_empty() or JSON.stringify(environment.get("music_profile", {})) != zero_music:
		failures.append("Zero-energy Craps projection changed the room.")
	CrapsRulesScript.settle_roll(table, {}, _craps_roll(4), rules)
	var first_energy := int(table.get("table_energy", 0))
	var first_projection: Dictionary = game.call("_project_table_energy", environment, table)
	if first_energy <= 0 or float(first_projection.get("intensity", 0.0)) <= 0.0 or not bool(first_projection.get("scenario_tuning_applied", false)) or str(first_projection.get("patron_line", "")).is_empty():
		failures.append("First made point did not produce scenario-tuned room energy, music intensity, and a patron line.")
	table["point"] = 5
	var working: Dictionary = table.get("working_bets", {})
	working["pass_line"] = 5
	table["working_bets"] = working
	CrapsRulesScript.settle_roll(table, {}, _craps_roll(5), rules)
	if int(table.get("hot_shooter_streak", 0)) != 2 or int(table.get("table_energy", 0)) <= first_energy:
		failures.append("Consecutive made points did not accelerate Craps table energy.")
	table["point"] = 6
	working = table.get("working_bets", {})
	working["pass_line"] = 5
	table["working_bets"] = working
	var before_seven := int(table.get("table_energy", 0))
	CrapsRulesScript.settle_roll(table, {}, _craps_roll(7), rules)
	if int(table.get("hot_shooter_streak", -1)) != 0 or int(table.get("table_energy", 0)) >= before_seven:
		failures.append("Craps seven-out did not reset the hot-shooter streak and reduce energy by tuning.")
	var unrelated_run: RunState = RunStateScript.new()
	unrelated_run.start_new("CRAPS-ENERGY-ISOLATION")
	unrelated_run.bankroll = 100
	var unrelated := {
		"id": "roulette_energy_isolation",
		"archetype_id": "small_underground_casino",
		"kind": "casino",
		"game_ids": ["roulette"],
		"game_states": {},
		"music_profile": {"volume": 0.2, "ambience": 0.31, "bpm": 76.0},
		"patron_state": {"line": "The rail watches the wheel."},
	}
	unrelated_run.current_environment = unrelated
	var unrelated_before := JSON.stringify(unrelated_run.current_environment)
	var unrelated_deltas := GameModule.empty_result_deltas()
	var unrelated_result := GameModule.build_action_result({
		"ok": true,
		"type": "game_action",
		"source_id": "roulette",
		"game_id": "roulette",
		"action_id": "spin",
		"action_kind": "legal",
		"stake": 0,
		"bankroll_delta": 0,
		"deltas": unrelated_deltas,
		"environment_id": "roulette_energy_isolation",
		"environment_archetype_id": "small_underground_casino",
		"message": "Roulette isolation boundary.",
	})
	GameModule.apply_result(unrelated_run, unrelated_result, unrelated_run.create_rng("roulette_energy_boundary"))
	if JSON.stringify(unrelated_run.current_environment) != unrelated_before or unrelated_run.current_environment.has("craps_room_energy"):
		failures.append("An unrelated Roulette result boundary leaked Craps music or patron projection state.")


func _check_craps_currency_routing(failures: Array) -> void:
	for game_id in ["blackjack", "baccarat", "roulette", "craps"]:
		var run_state: RunState = RunStateScript.new()
		run_state.start_new("CRAPS-CHIPS-REGRESSION-%s" % game_id)
		run_state.bankroll = 100
		run_state.grand_casino_chips = 50
		run_state.current_environment = {"id": "grand_casino_currency", "archetype_id": RunState.GRAND_CASINO_ARCHETYPE_ID, "kind": "boss"}
		var deltas := GameModule.empty_result_deltas()
		deltas["bankroll_delta"] = -5
		var result := GameModule.build_action_result({"ok": true, "type": "game_action", "source_id": game_id, "game_id": game_id, "action_id": "blackjack_place_bet" if game_id == "blackjack" else "settle", "action_kind": "legal", "stake": 5, "bankroll_delta": -5, "deltas": deltas, "environment_id": "grand_casino_currency", "environment_archetype_id": RunState.GRAND_CASINO_ARCHETYPE_ID, "message": "Currency seam fixture."})
		result["baccarat_total_wager"] = 5
		result["roulette_total_wager"] = 5
		result["craps_total_wager"] = 5
		GameModule.apply_result(run_state, result, run_state.create_rng("currency_apply"))
		if run_state.bankroll != 100 or run_state.grand_casino_chips != 45 or str(result.get("currency", "")) != "chips":
			failures.append("Grand Casino %s no longer routes through the shared chips seam." % game_id)
	var outside: RunState = RunStateScript.new()
	outside.start_new("CRAPS-CASH-ISOLATION")
	outside.bankroll = 100
	outside.grand_casino_chips = 50
	outside.current_environment = {"id": "tier_two_craps_fixture", "archetype_id": "small_underground_casino", "kind": "casino"}
	var outside_deltas := GameModule.empty_result_deltas()
	outside_deltas["bankroll_delta"] = -5
	var outside_result := GameModule.build_action_result({"ok": true, "type": "game_action", "source_id": "craps", "game_id": "craps", "action_id": "roll_craps", "action_kind": "legal", "stake": 5, "craps_total_wager": 5, "bankroll_delta": -5, "deltas": outside_deltas, "environment_id": "tier_two_craps_fixture", "environment_archetype_id": "small_underground_casino", "message": "Cash isolation fixture."})
	GameModule.apply_result(outside, outside_result, outside.create_rng("cash_apply"))
	if outside.bankroll != 95 or outside.grand_casino_chips != 50 or str(outside_result.get("currency", "cash")) == "chips":
		failures.append("Craps outside the Grand Casino touched chips instead of cash in the isolation fixture.")


func _check_craps_room_registration_and_duel(_game: GameModule, library: ContentLibrary, failures: Array) -> void:
	for archetype_id in [RunState.GRAND_CASINO_ARCHETYPE_ID, RunState.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID, RunState.GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID]:
		var archetype := _archetype_by_id(library, archetype_id)
		if not _craps_array(archetype.get("game_pool", [])).has("craps") or not _craps_array(archetype.get("required_game_ids", [])).has("craps"):
			failures.append("Craps is not guaranteed in Grand Casino table-game room %s." % archetype_id)
	var back_room := _archetype_by_id(library, RunState.GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID)
	var flags := _craps_dict(back_room.get("local_narrative_flags", {}))
	if str(flags.get("blackjack_boss_variant", "")) != "rourke_duel" or str(flags.get("showdown_game_id", "")) != "blackjack" or not _craps_array(back_room.get("required_game_ids", [])).has("blackjack"):
		failures.append("Back Room Craps registration displaced the required Rourke blackjack duel contract.")
	var ordinary_run: RunState = RunStateScript.new()
	ordinary_run.start_new("CRAPS-BACK-ROOM-GENERATION")
	var generated_back_room := EnvironmentInstance.from_archetype(back_room, 0, ordinary_run.create_rng("craps_back_room_generation"), library)
	if not generated_back_room.game_ids.has("blackjack") or not generated_back_room.game_ids.has("craps"):
		failures.append("Ordinary Back Room generation did not retain both registered table modules.")
	var blackjack: GameModule = _load_surface_contract_game(library, "blackjack", failures)
	if blackjack == null:
		return
	var duel_run: RunState = RunStateScript.new()
	duel_run.start_new("CRAPS-BACK-ROOM-DUEL-REGRESSION")
	var duel_environment := back_room.duplicate(true)
	duel_environment["id"] = "grand_casino_back_room_duel_regression"
	duel_environment["archetype_id"] = RunState.GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID
	duel_run.current_environment = duel_environment
	duel_run.narrative_flags["grand_casino_showdown_active"] = true
	duel_run.narrative_flags["grand_casino_showdown_step"] = RunState.GRAND_CASINO_SHOWDOWN_STEP_DUEL
	duel_run.narrative_flags["grand_casino_duel_state"] = {"status": "active"}
	if not bool(blackjack.call("_is_rourke_duel", duel_run, duel_environment)):
		failures.append("Rourke's Back Room still contains blackjack but no longer forces its boss-duel path.")
	var app_value: Variant = MainScene.instantiate()
	if not app_value is Control:
		failures.append("Back Room duel selection regression could not instantiate FoundationMain.")
		return
	var app: Control = app_value
	root.add_child(app)
	if not bool(app.call("uses_foundation_runtime")):
		app.call("_ready")
	duel_environment["game_ids"] = ["craps", "blackjack"]
	duel_run.current_environment = duel_environment
	app.set("run_state", duel_run)
	var entered := bool(app.call("enter_game", "craps", "craps"))
	var active_game_value: Variant = app.get("current_game")
	var active_game_id := ""
	if active_game_value is GameModule:
		active_game_id = str((active_game_value as GameModule).definition.get("id", ""))
	if not entered or active_game_id != "blackjack" or str(app.get("current_game_state_key")) != "blackjack":
		failures.append("DUEL allowed the registered Craps table to present or launch instead of forcing Rourke's blackjack surface.")
	_sb4_dispose_app(app)


func _craps_rule_table(base_table: Dictionary, point: int, working_overrides: Dictionary) -> Dictionary:
	var table := base_table.duplicate(true)
	table["point"] = point
	var working := {"pass_line": 0, "dont_pass": 0, "pass_odds": 0, "come": {}, "dont_come": {}, "come_odds": {}, "place": {}}
	for key in working_overrides.keys():
		working[key] = working_overrides[key]
	table["working_bets"] = working
	table["hot_shooter_streak"] = 0
	table["table_energy"] = 0
	return table


func _craps_roll(total: int) -> Dictionary:
	var first := clampi(total - 1, 1, 6)
	return {"dice": [first, total - first], "total": total, "initial_total": total, "setting_bias_applied": false}


func _craps_target_index(targets_value: Variant, target_id: String) -> int:
	var targets := _craps_array(targets_value)
	for index in range(targets.size()):
		if typeof(targets[index]) == TYPE_DICTIONARY and str((targets[index] as Dictionary).get("id", "")) == target_id:
			return index
	return -1


func _craps_dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _craps_array(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []


func _craps_int_array(value: Variant) -> Array:
	var result: Array = []
	for entry in _craps_array(value):
		result.append(int(entry))
	return result

func _check_crew_poker_contract(library: ContentLibrary, failures: Array) -> void:
	var definition := library.game("crew_draw_poker")
	if definition.is_empty():
		failures.append("Crew draw poker is missing from production game content.")
		return
	var poker_archetype := library.environment_archetype("small_underground_casino")
	var poker_layers: Dictionary = poker_archetype.get("layers", {}) if typeof(poker_archetype.get("layers", {})) == TYPE_DICTIONARY else {}
	var club: Dictionary = poker_layers.get("club", {}) if typeof(poker_layers.get("club", {})) == TYPE_DICTIONARY else {}
	var back_room: Dictionary = poker_layers.get("back_room", {}) if typeof(poker_layers.get("back_room", {})) == TYPE_DICTIONARY else {}
	var back_layout: Dictionary = back_room.get("layout", {}) if typeof(back_room.get("layout", {})) == TYPE_DICTIONARY else {}
	var game_spots: Array = back_layout.get("game_spots", []) if typeof(back_layout.get("game_spots", [])) == TYPE_ARRAY else []
	var stable_position := false
	if game_spots.size() == 1 and typeof(game_spots[0]) == TYPE_ARRAY:
		var position: Array = game_spots[0]
		stable_position = position.size() == 2 and int(position[0]) == 450 and int(position[1]) == 218
	var game_count: Array = back_room.get("game_count", []) if typeof(back_room.get("game_count", [])) == TYPE_ARRAY else []
	var exact_count := game_count.size() == 2 and int(game_count[0]) == 1 and int(game_count[1]) == 1
	var back_pool := _string_array(back_room.get("game_pool", []))
	var back_required := _string_array(back_room.get("required_game_ids", []))
	var exact_pool := back_pool.size() == 1 and str(back_pool[0]) == "crew_draw_poker"
	var exact_required := back_required.size() == 1 and str(back_required[0]) == "crew_draw_poker"
	if not stable_position or not exact_pool or not exact_required or not exact_count:
		failures.append("Crew poker must furnish exactly one stable table in the L3 back room.")
	if _string_array(poker_archetype.get("game_pool", [])).has("crew_draw_poker") or _string_array(club.get("game_pool", [])).has("crew_draw_poker"):
		failures.append("Crew poker leaked out of the nested L3 game pool into the public Punchline layer.")
	var game: GameModule = CrewDrawPokerGameScript.new()
	game.setup(definition, library)
	var straight_flush := [_poker_card(10, 1), _poker_card(11, 1), _poker_card(12, 1), _poker_card(13, 1), _poker_card(14, 1)]
	var wheel := [_poker_card(14, 0), _poker_card(2, 1), _poker_card(3, 2), _poker_card(4, 3), _poker_card(5, 0)]
	var six_high := [_poker_card(2, 0), _poker_card(3, 1), _poker_card(4, 2), _poker_card(5, 3), _poker_card(6, 0)]
	var full_house := [_poker_card(9, 0), _poker_card(9, 1), _poker_card(9, 2), _poker_card(3, 0), _poker_card(3, 1)]
	var one_pair := [_poker_card(11, 0), _poker_card(11, 1), _poker_card(9, 2), _poker_card(6, 3), _poker_card(3, 0)]
	var two_pair_ace := [_poker_card(14, 0), _poker_card(14, 1), _poker_card(7, 2), _poker_card(7, 3), _poker_card(13, 0)]
	var two_pair_queen := [_poker_card(14, 2), _poker_card(14, 3), _poker_card(7, 0), _poker_card(7, 1), _poker_card(12, 0)]
	var weak_hand := [_poker_card(14, 0), _poker_card(10, 1), _poker_card(8, 2), _poker_card(6, 3), _poker_card(3, 0)]
	if int(CrewPokerModelScript.evaluate_hand(straight_flush).get("category", -1)) != 8:
		failures.append("Crew poker did not evaluate a royal straight flush.")
	if CrewPokerModelScript.compare_hands(wheel, six_high) >= 0:
		failures.append("Crew poker wheel straight incorrectly beat a six-high straight.")
	if int(CrewPokerModelScript.evaluate_hand(full_house).get("category", -1)) != 6:
		failures.append("Crew poker did not evaluate a full house.")
	if CrewPokerModelScript.compare_hands(two_pair_ace, two_pair_queen) <= 0:
		failures.append("Crew poker two-pair kicker comparison failed.")
	var split := CrewPokerModelScript.split_pot(11, ["a", "b", "c"])
	if int(split.get("a", 0)) != 4 or int(split.get("b", 0)) != 4 or int(split.get("c", 0)) != 3:
		failures.append("Crew poker split-pot remainder math was not deterministic: %s." % JSON.stringify(split))
	_check_crew_poker_save_compat(failures)
	var property_rng := RngStream.new()
	property_rng.configure(8062)
	for sample in range(300):
		var deck := CardShoeScript.build_shoe(1, property_rng)
		var draw := CardShoeScript.draw_cards(deck, 10)
		var cards: Array = draw.get("cards", [])
		var a := cards.slice(0, 5)
		var b := cards.slice(5, 10)
		if CrewPokerModelScript.compare_hands(a, b) != -CrewPokerModelScript.compare_hands(b, a):
			failures.append("Crew poker comparison symmetry failed at property sample %d." % sample)
			break

	for member_id in CrewPokerCrewStateScript.MEMBER_IDS:
		var policy_a := RngStream.new()
		var policy_b := RngStream.new()
		policy_a.configure(44221)
		policy_b.configure(44221)
		var actions_a: Array = []
		var actions_b: Array = []
		for index in range(40):
			actions_a.append(CrewPokerModelScript.npc_action(member_id, two_pair_ace, "after", index % 2 == 0, policy_a))
			actions_b.append(CrewPokerModelScript.npc_action(member_id, two_pair_ace, "after", index % 2 == 0, policy_b))
		if actions_a != actions_b:
			failures.append("Crew poker policy was not deterministic for %s." % member_id)

	for member_id in CrewPokerCrewStateScript.MEMBER_IDS:
		for authored_value in CrewPokerModelScript.patterns(member_id):
			var authored: Dictionary = authored_value
			var copy := "%s %s" % [str(authored.get("line", "")), str(authored.get("quirk", ""))]
			if copy.to_lower().contains("tell"):
				failures.append("Crew poker authored observation labels itself for %s." % member_id)
			var condition := str(authored.get("condition", ""))
			var fixture := two_pair_ace if condition == "strong" else one_pair if condition == "one_pair" else six_high if condition == "made_straight" else weak_hand
			var action := "call" if condition == "strong" else "raise" if condition == "weak_aggression" else "draw"
			var draws := -1
			if not CrewPokerModelScript.condition_matches(condition, fixture, action, draws):
				failures.append("Crew poker authored observation condition fixture did not match %s/%s." % [member_id, condition])
			var frequency_rng := RngStream.new()
			frequency_rng.configure(99001 + int(authored.get("frequency_percent", 0)))
			var shown := 0
			for _sample in range(1000):
				var selected := CrewPokerModelScript.surface_pattern(member_id, fixture, action, draws, frequency_rng)
				if str(selected.get("state_key", "")) == str(authored.get("state_key", "")):
					shown += 1
			var expected := int(authored.get("frequency_percent", 0)) * 10
			if absi(shown - expected) > 80:
				failures.append("Crew poker authored observation frequency drifted for %s: got %d/1000, expected %d/1000." % [member_id, shown, expected])

	_check_crew_poker_rotation_and_gate(game, failures)
	var production_evidence := _check_crew_poker_state_machine(game, one_pair, failures)
	_check_crew_poker_signed_cash(game, failures)
	var public_surfaces: Array = production_evidence.get("surfaces", [])
	var public_results: Array = production_evidence.get("results", [])
	public_surfaces.append_array(_check_crew_poker_presentation_channels(game, failures))

	var tuning := CrewPokerModelScript.config()
	var hand_cap := int(tuning.get("session_hand_cap", 5))
	var swing_cap := int(tuning.get("session_swing_cap", 60))
	var maximum_call_hand_cost := int(tuning.get("ante", 2)) + 2 * (int(tuning.get("bet_unit", 2)) + int(tuning.get("raise_unit", 2)))
	if swing_cap < hand_cap * maximum_call_hand_cost:
		failures.append("Crew poker session swing cap cannot fund legal calls through the authored hand cap.")
	var capped_session: RunState = RunStateScript.new()
	capped_session.start_new("CREW-POKER-CAPPED-SESSION")
	capped_session.bankroll = 10000
	capped_session.crew_add_trust("crew_mags", CrewPokerCrewStateScript.rank_threshold("associate"), "fixture")
	_poker_install_table(game, capped_session, "capped_session", ["crew_mags", "crew_lucky"])
	var capped_path_ok := true
	for hand_index in range(hand_cap):
		for action_value in [
			{"id": "deal", "ui": {}},
			{"id": "call", "ui": {}},
			{"id": "draw", "ui": {"poker_held": [0, 2]}},
			{"id": "call", "ui": {}},
		]:
			var action: Dictionary = action_value
			var legal_ids: Array = []
			for legal_value in game.legal_actions(capped_session, capped_session.current_environment):
				if typeof(legal_value) == TYPE_DICTIONARY:
					legal_ids.append(str((legal_value as Dictionary).get("id", "")))
			var action_id := str(action.get("id", ""))
			if not legal_ids.has(action_id):
				failures.append("Crew poker capped session lost legal action %s on hand %d before resolution." % [action_id, hand_index])
				capped_path_ok = false
				break
			var capped_result := _poker_apply_action(game, capped_session, action_id, action.get("ui", {}), "cap_%d_%s" % [hand_index, action_id])
			if not bool(capped_result.get("ok", false)):
				failures.append("Crew poker capped session rejected legal action %s on hand %d." % [action_id, hand_index])
				capped_path_ok = false
				break
		if not capped_path_ok:
			break
		var capped_table := _poker_table(capped_session)
		if hand_index < hand_cap - 1 and (str(capped_table.get("phase", "")) != "idle" or bool(capped_table.get("session_settled", false))):
			failures.append("Crew poker capped session settled before its authored final hand.")
			capped_path_ok = false
			break
		if hand_index == hand_cap - 1 and (int(capped_table.get("hand_number", 0)) != hand_cap or not bool(capped_table.get("session_settled", false))):
			failures.append("Crew poker capped session did not settle exactly after its authored final hand.")

	var threshold := int(tuning.get("learned_exposures", 3))
	var learned_member := "crew_mags"
	var learning: RunState = RunStateScript.new()
	learning.start_new("CREW-POKER-LEARNING")
	learning.bankroll = 10000
	learning.crew_add_trust(learned_member, CrewPokerCrewStateScript.rank_threshold("associate"), "fixture")
	var learned_at := -1
	for session_index in range(48):
		_poker_install_table(game, learning, "learn_session_%d" % session_index, [learned_member, "crew_lucky"])
		for hand_index in range(hand_cap):
			if learning.tell_learned(learned_member):
				break
			var hand_actions := [
				{"id": "deal", "ui": {}},
				{"id": "call", "ui": {}},
				{"id": "draw", "ui": {"poker_held": [0, 2]}},
				{"id": "call", "ui": {}},
			]
			for action_value in hand_actions:
				var action: Dictionary = action_value
				var action_result := _poker_apply_action(game, learning, str(action.get("id", "")), action.get("ui", {}), "learn_%d_%d_%s" % [session_index, hand_index, str(action.get("id", ""))])
				public_results.append(action_result.duplicate(true))
				public_surfaces.append(game.surface_state(learning, learning.current_environment, action.get("ui", {})))
				if not bool(action_result.get("ok", false)):
					failures.append("Crew poker legal learning path failed at session %d hand %d action %s." % [session_index, hand_index, str(action.get("id", ""))])
					break
			if learning.tell_learned(learned_member):
				learned_at = _poker_max_observation_count(learning, learned_member)
				break
		if learned_at >= 0:
			break
	if learned_at != threshold:
		failures.append("Crew poker genuine-play learning did not flip exactly at %d verified showdowns; observed counter %d." % [threshold, learned_at])
	var learning_save := learning.to_dict()
	var restored: RunState = RunStateScript.new()
	restored.from_dict(learning_save)
	if not restored.tell_learned(learned_member):
		failures.append("Crew poker learned state did not survive save/load.")

	var fold_heavy: RunState = RunStateScript.new()
	fold_heavy.start_new("CREW-POKER-FOLDS")
	fold_heavy.bankroll = 10000
	fold_heavy.crew_add_trust(learned_member, CrewPokerCrewStateScript.rank_threshold("associate"), "fixture")
	for session_index in range(4):
		_poker_install_table(game, fold_heavy, "fold_session_%d" % session_index, [learned_member, "crew_lucky"])
		for hand_index in range(hand_cap):
			_poker_apply_action(game, fold_heavy, "deal", {}, "fold_deal_%d_%d" % [session_index, hand_index])
			var fold_result := _poker_apply_action(game, fold_heavy, "fold", {}, "fold_hand_%d_%d" % [session_index, hand_index])
			public_results.append(fold_result)
	if fold_heavy.tell_learned(learned_member) or _poker_max_observation_count(fold_heavy, learned_member) != 0:
		failures.append("Crew poker production fold-heavy sessions taught a showdown-gated observation.")

	var trust_run: RunState = RunStateScript.new()
	trust_run.start_new("CREW-POKER-TRUST")
	trust_run.bankroll = 1000
	trust_run.crew_add_trust("crew_mags", CrewPokerCrewStateScript.rank_threshold("associate"), "fixture")
	var trust_before := trust_run.crew_trust("crew_mags")
	var grievance_before := JSON.stringify(trust_run.crew_grievances())
	_poker_install_table(game, trust_run, "trust_session", ["crew_mags", "crew_lucky"])
	for hand_index in range(hand_cap):
		_poker_apply_action(game, trust_run, "deal", {}, "trust_deal_%d" % hand_index)
		_poker_apply_action(game, trust_run, "fold", {}, "trust_fold_%d" % hand_index)
	if trust_run.crew_trust("crew_mags") - trust_before != int(CrewPokerModelScript.config().get("session_trust", 2)):
		failures.append("Crew poker production session settlement did not accrue data-tuned trust.")
	trust_run.crew_record_poker_session(["crew_mags", "crew_lucky"], 14)
	trust_run.crew_record_poker_session(["crew_mags", "crew_lucky"], 14)
	if trust_run.crew_trust("crew_mags") <= trust_before + int(CrewPokerModelScript.config().get("session_trust", 2)) * 3:
		failures.append("Crew poker repeated hustle did not add data-tuned respect.")
	if JSON.stringify(trust_run.crew_grievances()) != grievance_before:
		failures.append("Crew poker wrote a grievance during trust-only sessions.")

	var save_projections: Array = production_evidence.get("saves", [])
	save_projections.append(learning_save)
	_check_crew_poker_hidden_leaks(learning, save_projections, public_surfaces, public_results, failures)


func _check_crew_poker_save_compat(failures: Array) -> void:
	var fresh: RunState = RunStateScript.new()
	fresh.start_new("CREW-POKER-SAVE-COMPAT")
	if fresh.crew_pattern_memory.is_empty():
		failures.append("Fresh runs did not initialize neutral Crew poker observation memory.")
	var fresh_save := fresh.to_dict()
	var fresh_restored: RunState = RunStateScript.new()
	fresh_restored.from_dict(fresh_save)
	if JSON.stringify(fresh_restored.to_dict()) != JSON.stringify(fresh_save):
		failures.append("Fresh neutral Crew poker memory was not byte-identical across save/load.")

	var minimal_save := fresh_save.duplicate(true)
	var minimal_crew: Dictionary = minimal_save.get("crew_state", {})
	minimal_crew["p"] = {}
	minimal_crew["m"] = {}
	minimal_save["crew_state"] = minimal_crew
	var minimal_restored: RunState = RunStateScript.new()
	minimal_restored.from_dict(minimal_save)
	if JSON.stringify(minimal_restored.to_dict()) != JSON.stringify(minimal_save):
		failures.append("Empty legacy Crew poker projections acquired neutral member keys during save/load.")
	if not minimal_restored.crew_pattern_memory.is_empty() or not minimal_restored.crew_match_marks.is_empty():
		failures.append("Empty legacy Crew poker projections were expanded in runtime memory during load.")

	var authored_patterns := CrewPokerModelScript.patterns("crew_mags")
	if authored_patterns.is_empty():
		failures.append("Crew poker save compatibility fixture could not find an authored observation.")
		return
	var state_key := str((authored_patterns[0] as Dictionary).get("state_key", ""))
	minimal_restored.crew_record_pattern("crew_mags", state_key)
	var counters: Dictionary = minimal_restored.crew_pattern_memory.get("crew_mags", {})
	if int(counters.get(state_key, 0)) != 1:
		failures.append("Gameplay did not lazily initialize an empty legacy Crew poker observation projection.")
	minimal_restored.crew_record_poker_session(["crew_mags"], 999)
	if int(minimal_restored.crew_match_marks.get("crew_mags", 0)) != 1:
		failures.append("Gameplay did not lazily initialize an empty legacy Crew poker match projection.")


func _poker_card(rank: int, suit: int) -> Dictionary:
	return {"rank": rank, "suit": suit, "deck": 0}


func _check_crew_poker_rotation_and_gate(game: GameModule, failures: Array) -> void:
	var residents := ["crew_mags", "crew_lucky", "crew_rook"]
	var rotations := {}
	for seed in range(12):
		var run_state: RunState = RunStateScript.new()
		run_state.start_new("CREW-POKER-ROTATION-%d" % seed)
		var environment := _poker_environment(residents)
		var first_rng := RngStream.new()
		first_rng.configure(6200 + seed)
		var second_rng := RngStream.new()
		second_rng.configure(6200 + seed)
		var first := game.generate_environment_state(run_state, environment, first_rng)
		var second := game.generate_environment_state(run_state, environment, second_rng)
		if JSON.stringify(first.get("members", [])) != JSON.stringify(second.get("members", [])):
			failures.append("Crew poker resident rotation was not deterministic for seed %d." % seed)
		var members: Array = first.get("members", [])
		if members.size() < 2 or members.size() > 3:
			failures.append("Crew poker rotation did not seat two or three residents.")
		for member_id in members:
			if not residents.has(str(member_id)):
				failures.append("Crew poker ignored the L3 resident seam and seated %s." % str(member_id))
		rotations[JSON.stringify(members)] = true
	if rotations.size() < 2:
		failures.append("Crew poker seeded rotation did not produce distinct resident tables.")
	var fallback_run: RunState = RunStateScript.new()
	fallback_run.start_new("CREW-POKER-FALLBACK")
	var fallback_rng_a := RngStream.new()
	fallback_rng_a.configure(7261)
	var fallback_rng_b := RngStream.new()
	fallback_rng_b.configure(7261)
	var fallback_a := game.generate_environment_state(fallback_run, _poker_environment(["crew_mags"]), fallback_rng_a)
	var fallback_b := game.generate_environment_state(fallback_run, _poker_environment(["crew_mags"]), fallback_rng_b)
	var fallback_members: Array = fallback_a.get("members", [])
	if fallback_members.size() < 2 or fallback_members.size() > 3 or JSON.stringify(fallback_members) != JSON.stringify(fallback_b.get("members", [])):
		failures.append("Crew poker seeded all-Crew fallback did not deterministically seat two or three members.")

	var gate_run: RunState = RunStateScript.new()
	gate_run.start_new("CREW-POKER-GATE")
	_poker_install_table(game, gate_run, "gate", ["crew_mags", "crew_lucky"])
	gate_run.crew_add_trust("crew_rook", CrewPokerCrewStateScript.rank_threshold("associate"), "non_present_fixture")
	if not game.legal_actions(gate_run, gate_run.current_environment).is_empty():
		failures.append("Crew poker accepted an associate who was not at the table.")
	gate_run.crew_add_trust("crew_lucky", CrewPokerCrewStateScript.rank_threshold("associate"), "present_fixture")
	if game.legal_actions(gate_run, gate_run.current_environment).is_empty():
		failures.append("Crew poker did not accept an associate who was present at the table.")


func _check_crew_poker_state_machine(game: GameModule, tie_cards: Array, failures: Array) -> Dictionary:
	var evidence := {"surfaces": [], "results": [], "saves": []}
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("CREW-POKER-STATE-MACHINE")
	run_state.bankroll = 500
	run_state.grand_casino_chips = 777
	run_state.crew_add_trust("crew_lucky", CrewPokerCrewStateScript.rank_threshold("associate"), "fixture")
	var generated := _poker_install_table(game, run_state, "state_machine", ["crew_mags", "crew_lucky"])
	var chips_before := run_state.grand_casino_chips
	var cash_before := run_state.bankroll
	var deal := _poker_apply_action(game, run_state, "deal", {}, "state_deal")
	(evidence["results"] as Array).append(deal)
	var dealt := _poker_table(run_state)
	(evidence["surfaces"] as Array).append(game.surface_state(run_state, run_state.current_environment, {}))
	if not bool(deal.get("ok", false)) or str(dealt.get("phase", "")) != "before":
		failures.append("Crew poker production deal did not enter the first betting round.")
	var contribution_total := int(dealt.get("player_contribution", 0))
	for seat_value in dealt.get("seats", []):
		contribution_total += int((seat_value as Dictionary).get("contribution", 0))
	if int(dealt.get("pot", 0)) != contribution_total:
		failures.append("Crew poker ante/first-bet pot did not equal all contributions.")
	if run_state.bankroll != cash_before + int(deal.get("bankroll_delta", 0)) or run_state.grand_casino_chips != chips_before:
		failures.append("Crew poker ante did not settle in cash only.")
	var irregular_before := JSON.stringify(run_state.to_dict())
	for irregular_action in ["cash_out", "draw", "deal", "not_a_poker_move"]:
		var irregular := _poker_apply_action(game, run_state, irregular_action, {}, "state_irregular_%s" % irregular_action)
		(evidence["results"] as Array).append(irregular)
		if bool(irregular.get("ok", true)) or bool(irregular.get("host_apply_result", true)):
			failures.append("Crew poker accepted out-of-phase direct action %s." % irregular_action)
		if JSON.stringify(run_state.to_dict()) != irregular_before:
			failures.append("Crew poker out-of-phase action %s mutated state or cash." % irregular_action)
	var after_irregular := _poker_table(run_state)
	if str(after_irregular.get("phase", "")) != "before" or bool(after_irregular.get("session_settled", false)):
		failures.append("Crew poker live-hand cash-out rejection left the table stuck or settled.")

	var first_call_cost := int(dealt.get("to_call", 0))
	var pot_before_call := int(dealt.get("pot", 0))
	var first_call := _poker_apply_action(game, run_state, "call", {}, "state_first_call")
	(evidence["results"] as Array).append(first_call)
	var draw_state := _poker_table(run_state)
	(evidence["surfaces"] as Array).append(game.surface_state(run_state, run_state.current_environment, {"poker_held": [0, 1]}))
	if str(draw_state.get("phase", "")) != "draw" or int(draw_state.get("pot", 0)) != pot_before_call + first_call_cost:
		failures.append("Crew poker first call did not advance to one draw with correct pot accounting.")
	for seat_value in draw_state.get("seats", []):
		if bool((seat_value as Dictionary).get("active", false)) and int((seat_value as Dictionary).get("draw_count", -1)) < 0:
			failures.append("Crew poker active resident did not complete exactly one draw decision.")

	var pot_before_draw := int(draw_state.get("pot", 0))
	var contributions_before_draw := _poker_npc_contribution_total(draw_state)
	var draw_result := _poker_apply_action(game, run_state, "draw", {"poker_held": [0, 1]}, "state_draw")
	(evidence["results"] as Array).append(draw_result)
	var after_state := _poker_table(run_state)
	(evidence["surfaces"] as Array).append(game.surface_state(run_state, run_state.current_environment, {}))
	var npc_after_bet := _poker_npc_contribution_total(after_state) - contributions_before_draw
	if str(after_state.get("phase", "")) != "after" or int(after_state.get("pot", 0)) != pot_before_draw + npc_after_bet:
		failures.append("Crew poker draw/second-bet pot transition was inconsistent.")
	if typeof(after_state.get("player_cards", [])) != TYPE_ARRAY or (after_state.get("player_cards", []) as Array).size() != 5:
		failures.append("Crew poker one-draw path did not preserve a five-card hand.")

	# Keep the legal state-machine path intact, then pin the exposed hands and pot
	# for a deterministic tie/remainder fixture through the production resolver.
	after_state["player_cards"] = tie_cards.duplicate(true)
	var seats: Array = after_state.get("seats", [])
	for index in range(seats.size()):
		var seat: Dictionary = seats[index]
		seat["active"] = index == 0
		seat["cards"] = tie_cards.duplicate(true)
		seats[index] = seat
	after_state["seats"] = seats
	after_state["pot"] = 11
	after_state["to_call"] = 0
	after_state["session_swing"] = 0
	_poker_write_table(run_state, after_state)
	var showdown := _poker_apply_action(game, run_state, "call", {}, "state_showdown_tie")
	(evidence["results"] as Array).append(showdown)
	var settled := _poker_table(run_state)
	(evidence["surfaces"] as Array).append(game.surface_state(run_state, run_state.current_environment, {}))
	var last: Dictionary = settled.get("last_result", {}) if typeof(settled.get("last_result", {})) == TYPE_DICTIONARY else {}
	if str(settled.get("phase", "")) != "idle" or int(last.get("payout", -1)) != 6:
		failures.append("Crew poker production showdown did not split an odd $11 tie as $6/$5 in stable winner order.")
	if (last.get("winners", []) as Array).size() != 2:
		failures.append("Crew poker tie showdown did not retain both winners.")
	if run_state.grand_casino_chips != chips_before:
		failures.append("Crew poker touched casino chips instead of cash during a full hand.")
	var idle_before_irregular := JSON.stringify(run_state.to_dict())
	var idle_call := _poker_apply_action(game, run_state, "call", {}, "state_idle_call_rejection")
	(evidence["results"] as Array).append(idle_call)
	if bool(idle_call.get("ok", true)) or JSON.stringify(run_state.to_dict()) != idle_before_irregular:
		failures.append("Crew poker accepted an out-of-phase call after showdown or mutated the settled hand.")

	var midhand_run: RunState = RunStateScript.new()
	midhand_run.start_new("CREW-POKER-MIDHAND")
	midhand_run.bankroll = 100
	midhand_run.crew_add_trust("crew_mags", CrewPokerCrewStateScript.rank_threshold("associate"), "fixture")
	_poker_install_table(game, midhand_run, "midhand", ["crew_mags", "crew_lucky"])
	_poker_apply_action(game, midhand_run, "deal", {}, "midhand_deal")
	var midhand_save := midhand_run.to_dict()
	(evidence["saves"] as Array).append(midhand_save)
	var midhand_restore: RunState = RunStateScript.new()
	midhand_restore.from_dict(midhand_save)
	if JSON.stringify(midhand_restore.current_environment.get("game_states", {})) != JSON.stringify(midhand_run.current_environment.get("game_states", {})):
		failures.append("Crew poker save/load changed mid-hand table state.")

	var cap := int(CrewPokerModelScript.config().get("session_swing_cap", 24))
	var blocked := _poker_table(midhand_run)
	blocked["session_swing"] = -cap + 1
	blocked["to_call"] = 2
	_poker_write_table(midhand_run, blocked)
	var blocked_before := JSON.stringify(_poker_table(midhand_run))
	var blocked_cash := midhand_run.bankroll
	var blocked_chips := midhand_run.grand_casino_chips
	var rejected := _poker_apply_action(game, midhand_run, "call", {}, "full_swing_rejection")
	if bool(rejected.get("ok", true)) or JSON.stringify(_poker_table(midhand_run)) != blocked_before or midhand_run.bankroll != blocked_cash or midhand_run.grand_casino_chips != blocked_chips:
		failures.append("Crew poker did not reject a full wager beyond the remaining negative swing room atomically.")
	var capped_state := generated.duplicate(true)
	capped_state["session_swing"] = cap - 1
	if int(game.call("_win_room", capped_state, 1000)) != 1:
		failures.append("Crew poker positive session swing cap was not enforced.")
	var idle_surface := game.surface_state(run_state, run_state.current_environment, {})
	_check_idle_animation_liveness_contract(idle_surface, "Crew poker table surface", failures)
	var harness := SurfaceHarness.new()
	harness.setup(idle_surface)
	game.draw_surface(harness, idle_surface, {"contract_harness": true, "viewport_size": Vector2(1280, 720)})
	if not harness.labels.has("BACK-ROOM DRAW") or not _surface_harness_has_action(harness, "poker_deal") or not _surface_harness_has_action(harness, "poker_cash_out"):
		failures.append("Crew poker 1280x720 renderer lost its title or idle action hit regions.")
	var board := Rect2(Vector2.ZERO, Vector2(ArtContractsScript.GAME_BOARD_SIZE))
	for hit_value in harness.hit_regions:
		var hit: Dictionary = hit_value
		var rect: Rect2 = hit.get("rect", Rect2())
		if rect.size.x <= 0.0 or rect.size.y <= 0.0 or not board.encloses(rect):
			failures.append("Crew poker renderer exposed an empty or out-of-board hit target: %s." % str(rect))
	var draw_surface: Dictionary = (evidence["surfaces"] as Array)[1] if (evidence["surfaces"] as Array).size() > 1 else {}
	var draw_harness := SurfaceHarness.new()
	draw_harness.setup(draw_surface)
	game.draw_surface(draw_harness, draw_surface, {"contract_harness": true, "viewport_size": Vector2(1280, 720)})
	if _surface_hit_count(draw_harness, "poker_card") != 5 or not _surface_harness_has_action(draw_harness, "poker_draw") or not _surface_harness_has_action(draw_harness, "poker_fold"):
		failures.append("Crew poker draw renderer did not expose five card targets plus draw/fold controls.")
	var canvas: Control = GameSurfaceCanvasScript.new()
	canvas.size = Vector2(ArtContractsScript.GAME_BOARD_SIZE)
	root.add_child(canvas)
	canvas.call("set_game_module", game)
	canvas.call("render_game_snapshot", idle_surface)
	canvas.call("reset_performance_counters")
	var motion_before: Dictionary = canvas.call("debug_surface_motion_sample")
	for _frame_index in range(12):
		canvas.call("debug_advance_idle_liveness", 1.0 / 60.0)
	var motion_after: Dictionary = canvas.call("debug_surface_motion_sample")
	var motion_runtime: Dictionary = canvas.call("surface_runtime_status")
	if motion_before == motion_after or int(motion_runtime.get("surface_animation_redraw_count", 0)) <= 0:
		failures.append("Crew poker renderer motion/liveness counter did not advance with zero input.")
	var reduced_surface := idle_surface.duplicate(true)
	reduced_surface["reduce_motion"] = true
	canvas.call("render_game_snapshot", reduced_surface)
	canvas.call("reset_performance_counters")
	var reduced_before: Dictionary = canvas.call("debug_surface_motion_sample")
	for _frame_index in range(12):
		canvas.call("debug_advance_idle_liveness", 1.0 / 60.0)
	var reduced_after: Dictionary = canvas.call("debug_surface_motion_sample")
	var reduced_runtime: Dictionary = canvas.call("surface_runtime_status")
	if reduced_before != reduced_after or int(reduced_runtime.get("surface_animation_redraw_count", 0)) != 0:
		failures.append("Crew poker reduce-motion did not freeze renderer motion and idle redraws.")
	root.remove_child(canvas)
	canvas.free()
	return evidence


func _check_crew_poker_signed_cash(game: GameModule, failures: Array) -> void:
	var swing_cap := int(CrewPokerModelScript.config().get("session_swing_cap", 60))
	for swing in [-7, 0, 7]:
		var run_state: RunState = RunStateScript.new()
		run_state.start_new("CREW-POKER-SIGNED-%d" % (swing + 10))
		run_state.bankroll = 100
		run_state.crew_add_trust("crew_mags", CrewPokerCrewStateScript.rank_threshold("associate"), "fixture")
		_poker_install_table(game, run_state, "signed_%d" % (swing + 10), ["crew_mags", "crew_lucky"])
		var table := _poker_table(run_state)
		table["hand_number"] = 1
		table["session_swing"] = swing
		_poker_write_table(run_state, table)
		var surface := game.surface_state(run_state, run_state.current_environment, {})
		var harness := SurfaceHarness.new()
		harness.setup(surface)
		game.draw_surface(harness, surface, {"contract_harness": true})
		var signed := "+%d" % swing if swing >= 0 else "%d" % swing
		if not harness.labels.has("POT $0   SESSION %s / %d" % [signed, swing_cap]):
			failures.append("Crew poker surface did not render supported signed session cash for %d." % swing)
		var settled := _poker_apply_action(game, run_state, "cash_out", {}, "signed_cash_%d" % (swing + 10))
		if not bool(settled.get("ok", false)) or not str(settled.get("message", "")).contains("at %s." % signed):
			failures.append("Crew poker settlement did not render supported signed session cash for %d." % swing)


func _check_crew_poker_presentation_channels(game: GameModule, failures: Array) -> Array:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("CREW-POKER-PRESENTATION")
	run_state.bankroll = 100
	run_state.crew_add_trust("crew_mags", CrewPokerCrewStateScript.rank_threshold("associate"), "fixture")
	_poker_install_table(game, run_state, "presentation", ["crew_mags", "crew_lucky"])
	_poker_apply_action(game, run_state, "deal", {}, "presentation_deal")
	var base_table := _poker_table(run_state)
	var surfaces: Array = []
	var chosen := {}
	for member_id in CrewPokerCrewStateScript.MEMBER_IDS:
		var patterns := CrewPokerModelScript.patterns(member_id)
		for index in range(patterns.size()):
			var pattern: Dictionary = patterns[index]
			var channel := str(pattern.get("channel", ""))
			if ["line", "portrait", "timing"].has(channel) and not chosen.has(channel):
				chosen[channel] = {"member_id": member_id, "index": index, "pattern": pattern}
	for required_channel in ["line", "portrait", "timing"]:
		if not chosen.has(required_channel):
			failures.append("Crew poker has no authored production fixture for %s presentation." % required_channel)
			continue
		var fixture: Dictionary = chosen[required_channel]
		var member_id := str(fixture.get("member_id", ""))
		var pattern: Dictionary = fixture.get("pattern", {})
		var table := base_table.duplicate(true)
		var companion := "crew_lucky" if member_id != "crew_lucky" else "crew_mags"
		table["members"] = [member_id, companion]
		var source_seats: Array = table.get("seats", [])
		var first_cards: Array = (source_seats[0] as Dictionary).get("cards", []).duplicate(true) if not source_seats.is_empty() else []
		var second_cards: Array = (source_seats[1] as Dictionary).get("cards", []).duplicate(true) if source_seats.size() > 1 else first_cards.duplicate(true)
		table["seats"] = [
			{"member_id": member_id, "cards": first_cards, "active": true, "revealed": false, "contribution": 2, "draw_count": 0, "last_action": "call"},
			{"member_id": companion, "cards": second_cards, "active": true, "revealed": false, "contribution": 2, "draw_count": 0, "last_action": "call"},
		]
		table["beat"] = {"m": member_id, "i": int(fixture.get("index", -1))}
		_poker_write_table(run_state, table)
		var surface := game.surface_state(run_state, run_state.current_environment, {})
		surfaces.append(surface)
		var observation: Dictionary = surface.get("observation", {}) if typeof(surface.get("observation", {})) == TYPE_DICTIONARY else {}
		if str(observation.get("channel", "")) != required_channel:
			failures.append("Crew poker production surface did not retain authored %s channel." % required_channel)
		var surface_text := JSON.stringify(surface)
		for hidden_token in [str(pattern.get("state_key", "")), str(pattern.get("condition", "")), "state_key", "condition", "frequency_percent", "learned_exposures"]:
			if not hidden_token.is_empty() and surface_text.contains(hidden_token):
				failures.append("Crew poker %s presentation leaked hidden token '%s'." % [required_channel, hidden_token])
		var harness := SurfaceHarness.new()
		harness.setup(surface)
		match required_channel:
			"line":
				game.draw_surface(harness, surface, {"contract_harness": true})
				if not harness.labels.has(str(pattern.get("line", "")).left(76)):
					failures.append("Crew poker line channel did not select its authored spoken line.")
			"portrait":
				harness.record_draw_rects = true
				game.draw_surface(harness, surface, {"contract_harness": true})
				var variant_found := false
				for seat_value in surface.get("seats", []):
					if typeof(seat_value) == TYPE_DICTIONARY and str((seat_value as Dictionary).get("member_id", "")) == member_id:
						variant_found = str((seat_value as Dictionary).get("portrait_variant", "")) == str(pattern.get("portrait_variant", ""))
				if not variant_found or not harness.labels.has(str(pattern.get("quirk", "")).left(76)):
					failures.append("Crew poker portrait channel did not project its pose and subtle quirk.")
				var no_beat_table := table.duplicate(true)
				no_beat_table["beat"] = {}
				_poker_write_table(run_state, no_beat_table)
				var no_beat_surface := game.surface_state(run_state, run_state.current_environment, {})
				var no_beat_harness := SurfaceHarness.new()
				no_beat_harness.setup(no_beat_surface)
				no_beat_harness.record_draw_rects = true
				game.draw_surface(no_beat_harness, no_beat_surface, {"contract_harness": true})
				if harness.draw_rect_records.size() <= no_beat_harness.draw_rect_records.size():
					failures.append("Crew poker portrait variant did not affect production renderer geometry.")
			"timing":
				harness.animation_elapsed = 0.0
				game.draw_surface(harness, surface, {"contract_harness": true})
				if harness.labels.has(str(pattern.get("line", "")).left(76)) or not harness.labels.has("The room holds one quiet beat."):
					failures.append("Crew poker timing channel did not hold its authored beat before the line.")
				var after_harness := SurfaceHarness.new()
				after_harness.setup(surface)
				after_harness.animation_elapsed = float(int(pattern.get("timing_msec", 0)) + 1) / 1000.0
				game.draw_surface(after_harness, surface, {"contract_harness": true})
				if not after_harness.labels.has(str(pattern.get("line", "")).left(76)):
					failures.append("Crew poker timing channel did not surface its line after the authored beat.")
	return surfaces


func _check_crew_poker_hidden_leaks(run_state: RunState, save_projection: Variant, surfaces: Array, results: Array, failures: Array) -> void:
	var forbidden: Array = ["state_key", "condition", "frequency_percent", "learned_exposures", "tell_learned"]
	for member_id in CrewPokerCrewStateScript.MEMBER_IDS:
		for pattern_value in CrewPokerModelScript.patterns(member_id):
			var pattern: Dictionary = pattern_value
			for token in [str(pattern.get("state_key", "")), str(pattern.get("condition", ""))]:
				if not token.is_empty() and not forbidden.has(token):
					forbidden.append(token)
	var projections := {
		"surface": surfaces,
		"action result": results,
		"story/log": run_state.story_log,
		"save": save_projection,
	}
	for projection_name in projections.keys():
		var public_text := JSON.stringify(projections[projection_name])
		for token_value in forbidden:
			var token := str(token_value)
			if public_text.contains(token):
				failures.append("Crew poker hidden authored token '%s' leaked through the public %s projection." % [token, str(projection_name)])


func _poker_install_table(game: GameModule, run_state: RunState, rng_scope: String, residents: Array) -> Dictionary:
	var environment := _poker_environment(residents)
	environment["id"] = "crew_poker_%s" % rng_scope
	var table_rng := run_state.create_rng("crew_poker_table:%s" % rng_scope)
	var generated := game.generate_environment_state(run_state, environment, table_rng)
	run_state.save_rng(table_rng)
	environment["game_states"] = {"crew_draw_poker": generated}
	run_state.current_environment = environment.duplicate(true)
	return generated


func _poker_environment(residents: Array) -> Dictionary:
	return {"id": "crew_poker_test", "archetype_id": "small_underground_casino", "kind": "crew", "layer_id": "back_room", "resident_member_ids": residents.duplicate(), "game_ids": ["crew_draw_poker"], "game_states": {}}


func _poker_apply_action(game: GameModule, run_state: RunState, action_id: String, ui_state: Dictionary, rng_scope: String) -> Dictionary:
	var rng := run_state.create_rng("crew_poker_action:%s" % rng_scope)
	var result := game.resolve_with_context(action_id, 2, run_state, run_state.current_environment, rng, ui_state)
	if bool(result.get("ok", false)):
		if bool(result.get("host_apply_result", false)):
			GameModule.apply_result(run_state, result, rng)
		else:
			run_state.save_rng(rng)
	return result


func _poker_table(run_state: RunState) -> Dictionary:
	var states: Dictionary = run_state.current_environment.get("game_states", {}) if typeof(run_state.current_environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var table: Variant = states.get("crew_draw_poker", {})
	return (table as Dictionary).duplicate(true) if typeof(table) == TYPE_DICTIONARY else {}


func _poker_write_table(run_state: RunState, table: Dictionary) -> void:
	var states: Dictionary = run_state.current_environment.get("game_states", {}) if typeof(run_state.current_environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	states = states.duplicate(true)
	states["crew_draw_poker"] = table.duplicate(true)
	run_state.current_environment["game_states"] = states


func _poker_npc_contribution_total(table: Dictionary) -> int:
	var total := 0
	for seat_value in table.get("seats", []):
		if typeof(seat_value) == TYPE_DICTIONARY:
			total += int((seat_value as Dictionary).get("contribution", 0))
	return total


func _poker_max_observation_count(run_state: RunState, member_id: String) -> int:
	var counters: Dictionary = run_state.crew_pattern_memory.get(member_id, {}) if typeof(run_state.crew_pattern_memory.get(member_id, {})) == TYPE_DICTIONARY else {}
	var maximum := 0
	for value in counters.values():
		maximum = maxi(maximum, int(value))
	return maximum

func _check_roulette_surface_contract(game: GameModule, failures: Array, library: ContentLibrary = null) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("ROULETTE-SURFACE-CONTRACT")
	run_state.bankroll = 1000
	var environment := _surface_contract_environment()
	environment["game_ids"] = ["roulette"]
	environment["economic_profile"] = {"stake_floor": 1, "stake_ceiling": 200}
	var table: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("roulette_contract_table"))
	if table.is_empty():
		failures.append("Roulette did not generate table state for an environment.")
		return
	if str(table.get("schema", "")) != "roulette_table_state":
		failures.append("Roulette generated table state did not expose the roulette schema.")
	var wheel_sequence := _string_array(table.get("wheel_sequence", []))
	if wheel_sequence.size() != 38 or not wheel_sequence.has("0") or not wheel_sequence.has("00"):
		failures.append("Roulette generated American table did not expose a 38-pocket wheel sequence.")
	var rules: Dictionary = table.get("rules", {}) if typeof(table.get("rules", {})) == TYPE_DICTIONARY else {}
	if str(table.get("variant", "")) != "american_double_zero" or int(rules.get("zero_count", 0)) != 2:
		failures.append("Roulette wheel type was not explicitly the American double-zero variant.")
	var physics_profile: Dictionary = table.get("physics_profile", {}) if typeof(table.get("physics_profile", {})) == TYPE_DICTIONARY else {}
	for physics_key in ["ball_initial_omega_min", "ball_initial_omega_max", "ball_angular_decel_min", "ball_angular_decel_max", "rotor_initial_omega_min", "rotor_initial_omega_max", "diamond_scatter_degrees", "pocket_depth", "micro_scatter"]:
		if not physics_profile.has(physics_key):
			failures.append("Roulette physics profile missing mutable attribute: %s." % physics_key)
	var wheel_bias: Dictionary = table.get("wheel_bias", {}) if typeof(table.get("wheel_bias", {})) == TYPE_DICTIONARY else {}
	if not ["outside_skew", "green_magnet"].has(str(wheel_bias.get("type", ""))):
		failures.append("Roulette table did not receive a persistent hidden wheel bias.")
	if (table.get("patrons", []) as Array).is_empty():
		failures.append("Roulette generated table did not include other table players.")
	if not (table.get("dealer_profile", {}) is Dictionary):
		failures.append("Roulette generated table did not include a dealer profile.")
	environment["game_states"] = {"roulette": table}
	run_state.current_environment = environment.duplicate(true)

	var surface := game.surface_state(run_state, environment, {})
	if str(surface.get("surface_renderer", "")) != "roulette":
		failures.append("Roulette surface did not route to the roulette renderer.")
	_check_idle_animation_liveness_contract(surface, "Roulette betting surface", failures)
	if not bool(surface.get("surface_controls_native", false)):
		failures.append("Roulette surface did not expose native table controls.")
	if not bool(surface.get("surface_animates_idle", false)):
		failures.append("Roulette betting surface must declare idle animation liveness for wheel and patron motion.")
	if bool(surface.get("surface_realtime_state_refresh", false)):
		failures.append("Roulette betting surface must not rebuild full realtime snapshots for idle animation.")
	var initial_recent: Array = _baccarat_dictionary_array(surface.get("recent_numbers", []))
	if not initial_recent.is_empty():
		failures.append("Roulette fresh table should start with an empty recent-number strip.")
	var patron_layout: Array = _baccarat_dictionary_array(surface.get("patron_layout", []))
	var surface_patrons: Array = _baccarat_dictionary_array(surface.get("patrons", []))
	if surface_patrons.size() > 3:
		failures.append("Roulette surface must cap visible table players at three to avoid overlap.")
	if patron_layout.size() != surface_patrons.size():
		failures.append("Roulette surface did not expose a patron layout entry for every visible table player.")
	var patron_board := Rect2(Vector2.ZERO, Vector2(ArtContractsScript.GAME_BOARD_SIZE))
	var seen_patron_rects: Array = []
	for patron_slot_value in patron_layout:
		if typeof(patron_slot_value) != TYPE_DICTIONARY:
			failures.append("Roulette patron layout entry was not a dictionary.")
			continue
		var patron_slot: Dictionary = patron_slot_value
		var patron_rect := _layout_rect_from_dict(patron_slot.get("rect", {}))
		if patron_rect.size.x <= 0.0 or patron_rect.size.y <= 0.0:
			failures.append("Roulette patron layout exposed an empty model hit rect.")
			continue
		if patron_rect.position.x < 748.0:
			failures.append("Roulette patron model was not placed on the right side: %s." % str(patron_rect))
		if not patron_board.encloses(patron_rect):
			failures.append("Roulette patron model hit rect is outside the board: %s." % str(patron_rect))
		for prior_rect in seen_patron_rects:
			if patron_rect.intersects(prior_rect):
				failures.append("Roulette patron model hit rects overlap: %s and %s." % [str(patron_rect), str(prior_rect)])
		seen_patron_rects.append(patron_rect)
	var patron_harness := SurfaceHarness.new()
	patron_harness.setup(surface)
	game.draw_surface(patron_harness, surface, {"contract_harness": true})
	if _surface_hit_count(patron_harness, "roulette_patron_focus") != surface_patrons.size():
		failures.append("Roulette did not register every visible table player as an interactive model.")
	var focus_click := _check_surface_command_non_mutating(game, "roulette_patron_focus", 0, false, {}, run_state, environment, "roulette patron focus", failures)
	var focus_ui: Dictionary = focus_click.get("ui_state", {})
	if int(focus_ui.get("focused_patron_index", -1)) != 0:
		failures.append("Roulette patron focus did not select the clicked table player.")
	var focused_surface := game.surface_state(run_state, environment, focus_ui)
	var focused_harness := SurfaceHarness.new()
	focused_harness.setup(focused_surface)
	game.draw_surface(focused_harness, focused_surface, {"contract_harness": true})
	if not _surface_harness_has_action(focused_harness, "roulette_patron_bet"):
		failures.append("Roulette focused table player did not expose follow/fade interaction buttons.")
	var targets: Array = surface.get("bet_targets", []) as Array
	if targets.size() < 140:
		failures.append("Roulette surface did not expose a full inside/outside betting layout.")
	for target_type in ["straight", "split", "street", "corner", "six_line", "trio", "top_line", "dozen", "column", "red", "black", "odd", "even", "low", "high"]:
		if not _roulette_targets_include_type(targets, target_type):
			failures.append("Roulette betting layout missing bet type: %s." % target_type)
	var straight_17_index := _roulette_target_index(targets, "straight", "17")
	if straight_17_index < 0:
		failures.append("Roulette betting layout did not expose a straight-up 17 target.")
		return
	var harness := SurfaceHarness.new()
	harness.setup(surface)
	game.draw_surface(harness, surface, {"contract_harness": true})
	if not harness.labels.has("RECENT"):
		failures.append("Roulette renderer did not expose a recent-number display.")
	if _surface_hit_count(harness, "roulette_bet") < targets.size():
		failures.append("Roulette renderer did not create hit regions for every bet target.")
	var information_rect: Rect2 = game.call("_roulette_information_panel_rect")
	var recent_rect: Rect2 = game.call("_roulette_recent_panel_rect")
	var dealer_rect: Rect2 = game.call("_roulette_dealer_panel_rect")
	var notice_rect: Rect2 = game.call("_roulette_table_notice_rect")
	if information_rect.intersects(recent_rect) or information_rect.intersects(dealer_rect):
		failures.append("Roulette compact bet information panel overlaps Recent Spins or the dealer station.")
	if information_rect.position.y <= recent_rect.end.y or information_rect.end.y >= dealer_rect.position.y:
		failures.append("Roulette compact bet information panel is not fully contained between Recent Spins and the dealer.")
	for target_value in targets:
		if typeof(target_value) != TYPE_DICTIONARY:
			continue
		var target_rect := _layout_rect_from_dict((target_value as Dictionary).get("rect", {}))
		if information_rect.intersects(target_rect):
			failures.append("Roulette compact bet information panel overlaps a betting target: %s." % str((target_value as Dictionary).get("label", "bet")))
			break
		if notice_rect.intersects(target_rect):
			failures.append("Roulette table notice overlaps a betting target: %s." % str((target_value as Dictionary).get("label", "bet")))
			break
	var game_board := Rect2(Vector2.ZERO, Vector2(ArtContractsScript.GAME_BOARD_SIZE))
	if not game_board.encloses(notice_rect) or notice_rect.position.x < 626.0 or notice_rect.position.y < 344.0:
		failures.append("Roulette table notice is not contained in the empty lower-right console area.")
	var roulette_bet_hit := _surface_harness_first_hit(harness, "roulette_bet", straight_17_index)
	_check_canvas_hit_dispatch(surface, roulette_bet_hit.get("rect", Rect2()), "roulette_bet", straight_17_index, "Roulette straight-bet canvas dispatch", failures)
	for action_id in ["roulette_read_wheel", "roulette_chip"]:
		if not _surface_harness_has_action(harness, action_id):
			failures.append("Roulette renderer missing surface action: %s." % action_id)
	var audio: Dictionary = surface.get("surface_audio", {}) if typeof(surface.get("surface_audio", {})) == TYPE_DICTIONARY else {}
	if str(audio.get("profile_id", "")) != "roulette_table":
		failures.append("Roulette surface audio did not expose the roulette_table profile.")
	var sync: Dictionary = audio.get("state_sync", {}) if typeof(audio.get("state_sync", {})) == TYPE_DICTIONARY else {}
	if str(sync.get("method", "")) != "roulette_table_state":
		failures.append("Roulette surface audio did not expose roulette_table_state sync.")
	var action_cues: Dictionary = audio.get("action_cues", {}) if typeof(audio.get("action_cues", {})) == TYPE_DICTIONARY else {}
	if action_cues.has("roulette_bet") or action_cues.has("roulette_patron_bet"):
		failures.append("Roulette chip placement audio must be emitted only after a bet command is accepted.")
	var blocked_surface := surface.duplicate(true)
	blocked_surface["surface_action_blocks"] = game.call("_surface_action_blocks", true)
	if not _surface_blocks_action(blocked_surface, "roulette_bet") or not _surface_blocks_action(blocked_surface, "roulette_spin"):
		failures.append("Roulette surface did not block betting/spinning during the spin animation.")

	var chip_denoms: Array = game.call("_chip_denominations", table)
	var contract_chip := 5 if chip_denoms.has(5) else int(chip_denoms[0])
	for chip_value in chip_denoms:
		var chip_ui := {"selected_chip": int(chip_value)}
		var chip_click := _check_surface_command_non_mutating(game, "roulette_bet", straight_17_index, false, chip_ui, run_state, environment, "roulette chip denomination %d" % int(chip_value), failures)
		var chip_state: Dictionary = chip_click.get("ui_state", {}) if typeof(chip_click.get("ui_state", {})) == TYPE_DICTIONARY else {}
		var chip_bets: Array = chip_state.get("roulette_bets", []) as Array
		if game.call("_total_wager", chip_bets) != int(chip_value):
			failures.append("Roulette chip denomination $%d did not place exactly that stake." % int(chip_value))
	var bet_click := _check_surface_command_non_mutating(game, "roulette_bet", straight_17_index, false, {"selected_chip": contract_chip}, run_state, environment, "roulette straight bet", failures)
	var bet_ui: Dictionary = bet_click.get("ui_state", {})
	var bet_total: int = game.call("_total_wager", bet_ui.get("roulette_bets", []))
	if bet_total != contract_chip:
		failures.append("Roulette straight bet did not create a $%d wager: %s." % [contract_chip, JSON.stringify(bet_click)])
	if str(bet_click.get("surface_audio_cue", "")) != "roulette_chip_place":
		failures.append("Roulette accepted direct bet did not return a post-validation chip-place cue.")
	var cash_fallback_run: RunState = RunStateScript.new()
	cash_fallback_run.start_new("ROULETTE-CASH-FALLBACK")
	cash_fallback_run.bankroll = contract_chip
	cash_fallback_run.grand_casino_chips = 0
	var cash_fallback_environment := environment.duplicate(true)
	cash_fallback_environment["id"] = "grand_casino_high_limit_cash_fallback"
	cash_fallback_environment["archetype_id"] = RunState.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID
	cash_fallback_run.set_environment(cash_fallback_environment)
	var cash_fallback_bet := game.surface_action_command("roulette_bet", straight_17_index, false, {"selected_chip": contract_chip}, cash_fallback_run, cash_fallback_run.current_environment)
	var cash_fallback_ui: Dictionary = cash_fallback_bet.get("ui_state", {}) if typeof(cash_fallback_bet.get("ui_state", {})) == TYPE_DICTIONARY else {}
	var cash_fallback_bets: Array = cash_fallback_ui.get("roulette_bets", []) as Array
	var cash_fallback_validation: Dictionary = game.call("_validate_roulette_bets", cash_fallback_bets, table, cash_fallback_run, cash_fallback_run.current_environment)
	var cash_fallback_surface := game.surface_state(cash_fallback_run, cash_fallback_run.current_environment, cash_fallback_ui)
	if game.call("_total_wager", cash_fallback_bets) != contract_chip or not bool(cash_fallback_validation.get("ok", false)) or int(cash_fallback_surface.get("bankroll", -1)) != contract_chip:
		failures.append("Grand Casino roulette did not expose zero-chip cash as usable betting capacity.")
	var red_index := _roulette_target_index(targets, "red", "1")
	if red_index < 0:
		failures.append("Roulette betting layout did not expose a RED outside target.")
	else:
		var outside_min_table := table.duplicate(true)
		var outside_min_rules: Dictionary = table.get("rules", {}) if typeof(table.get("rules", {})) == TYPE_DICTIONARY else {}
		outside_min_rules = outside_min_rules.duplicate(true)
		outside_min_rules["outside_min_each"] = 5
		outside_min_rules["table_max"] = 200
		outside_min_table["rules"] = outside_min_rules
		var outside_min_environment := environment.duplicate(true)
		outside_min_environment["game_states"] = {"roulette": outside_min_table}
		outside_min_environment["economic_profile"] = {"stake_floor": 1, "stake_ceiling": 200}
		var outside_click := _check_surface_command_non_mutating(game, "roulette_bet", red_index, false, {"selected_chip": 1}, run_state, outside_min_environment, "roulette direct outside minimum", failures)
		var outside_ui: Dictionary = outside_click.get("ui_state", {}) if typeof(outside_click.get("ui_state", {})) == TYPE_DICTIONARY else {}
		var outside_total: int = game.call("_total_wager", outside_ui.get("roulette_bets", []))
		if outside_total != 5:
			failures.append("Roulette direct outside bet with a small chip should raise to the $5 table minimum; got $%d." % outside_total)
		if int(outside_ui.get("selected_chip", 0)) != 5:
			failures.append("Roulette direct outside minimum raise did not update the selected chip display.")
		if str(outside_click.get("surface_audio_cue", "")) != "roulette_chip_place":
			failures.append("Roulette accepted outside bet did not return a post-validation chip-place cue.")
		var reject_table := outside_min_table.duplicate(true)
		var reject_rules := outside_min_rules.duplicate(true)
		reject_rules["table_max"] = 4
		reject_table["rules"] = reject_rules
		var reject_environment := environment.duplicate(true)
		reject_environment["game_states"] = {"roulette": reject_table}
		reject_environment["economic_profile"] = {"stake_floor": 1, "stake_ceiling": 4}
		var reject_click := _check_surface_command_non_mutating(game, "roulette_bet", red_index, false, {"selected_chip": 1}, run_state, reject_environment, "roulette rejected outside minimum", failures)
		var reject_ui: Dictionary = reject_click.get("ui_state", {}) if typeof(reject_click.get("ui_state", {})) == TYPE_DICTIONARY else {}
		var reject_total: int = game.call("_total_wager", reject_ui.get("roulette_bets", []))
		if reject_total != 0:
			failures.append("Roulette rejected outside minimum still changed the bet layout.")
		if not str(reject_click.get("surface_audio_cue", "")).is_empty():
			failures.append("Roulette rejected outside minimum returned a chip-place audio cue.")
	if game.wager_cost_for_context("spin_roulette", contract_chip, run_state, environment, bet_ui) != contract_chip:
		failures.append("Roulette wager cost did not reflect chips placed on the layout.")
	var spin_surface := game.surface_state(run_state, environment, bet_ui)
	if not bool(spin_surface.get("can_spin", false)):
		failures.append("Roulette surface did not become spin-ready after a valid bet.")
	var spin_harness := SurfaceHarness.new()
	spin_harness.setup(spin_surface)
	game.draw_surface(spin_harness, spin_surface, {"contract_harness": true})
	for action_id in ["roulette_spin", "roulette_clear"]:
		if not _surface_harness_has_action(spin_harness, action_id):
			failures.append("Roulette spin-ready renderer missing surface action: %s." % action_id)
	var spin_click := _check_surface_command_non_mutating(game, "roulette_spin", 0, false, bet_ui, run_state, environment, "roulette spin command", failures)
	if str(spin_click.get("action_id", "")) != "spin_roulette" or bool(spin_click.get("resolve", false)) or not bool(spin_click.get("preserve_surface_ui_state", false)):
		failures.append("Roulette first spin click did not arm the two-click legal roulette confirmation.")
	var armed_spin_ui: Dictionary = spin_click.get("ui_state", {})
	armed_spin_ui["selected_action_id"] = "spin_roulette"
	armed_spin_ui["selected_action_kind"] = "legal"
	var armed_surface := game.surface_state(run_state, environment, armed_spin_ui)
	if not _string_array(armed_surface.get("native_selected_surface_actions", [])).has("roulette_spin"):
		failures.append("Roulette armed spin was not reflected in native selected surface actions.")
	var confirm_spin := _check_surface_command_non_mutating(game, "roulette_spin", 0, false, armed_spin_ui, run_state, environment, "roulette confirm spin command", failures)
	if str(confirm_spin.get("action_id", "")) != "spin_roulette" or not bool(confirm_spin.get("resolve", false)):
		failures.append("Roulette second spin click did not resolve the confirmed spin.")
	var before := _run_state_result_snapshot(run_state)
	var result := game.resolve_with_context("spin_roulette", contract_chip, run_state, environment, run_state.create_rng("roulette_contract_spin"), confirm_spin.get("ui_state", {}))
	_check_action_result_shape(result, "legal", failures)
	_check_action_result_application_contract(before, run_state, result, "roulette spin result", failures)
	if not wheel_sequence.has(str(result.get("roulette_winning_number", ""))):
		failures.append("Roulette spin landed on a number outside the table wheel sequence.")
	if (result.get("roulette_spin_trajectory", []) as Array).size() < 48:
		failures.append("Roulette spin did not publish an efficient precomputed ball trajectory.")
	var spin_physics: Dictionary = result.get("roulette_spin_physics", {}) if typeof(result.get("roulette_spin_physics", {})) == TYPE_DICTIONARY else {}
	for key in ["drop_time", "deflector_index", "settle_time", "relative_angle", "capture_energy"]:
		if not spin_physics.has(key):
			failures.append("Roulette spin physics missing field: %s." % key)
	var persisted_table: Dictionary = ((environment.get("game_states", {}) as Dictionary).get("roulette", {}) as Dictionary)
	if int(persisted_table.get("spin_count", 0)) <= 0 or (persisted_table.get("last_result", {}) as Dictionary).is_empty():
		failures.append("Roulette did not persist the resolved table spin state.")
	var persisted_last_result: Dictionary = persisted_table.get("last_result", {}) if typeof(persisted_table.get("last_result", {})) == TYPE_DICTIONARY else {}
	var resolved_at_msec := int(persisted_last_result.get("resolved_at_msec", 0))
	var early_result_surface := game.surface_state(run_state, environment, {"surface_time_msec": resolved_at_msec + 100})
	var early_channels: Array = early_result_surface.get("surface_animation_channels", []) if typeof(early_result_surface.get("surface_animation_channels", [])) == TYPE_ARRAY else []
	var early_spin_channel: Dictionary = {}
	for channel_value in early_channels:
		if typeof(channel_value) == TYPE_DICTIONARY and str((channel_value as Dictionary).get("id", "")) == "roulette_spin":
			early_spin_channel = channel_value as Dictionary
			break
	if str(early_spin_channel.get("clock_source", "")) != "surface" or str(early_spin_channel.get("active_id", "")).is_empty():
		failures.append("Roulette spin animation was not bound to the pause-safe surface clock.")
	else:
		var long_run_spin_surface := early_result_surface.duplicate(true)
		long_run_spin_surface["surface_time_msec"] = resolved_at_msec + 100
		var spin_canvas: Control = GameSurfaceCanvasScript.new()
		spin_canvas.size = Vector2(ArtContractsScript.GAME_BOARD_SIZE)
		spin_canvas.render_game_snapshot(long_run_spin_surface)
		var spin_elapsed_msec := int(round(spin_canvas.surface_elapsed("roulette_spin") * 1000.0))
		if not spin_canvas.surface_animation_active("roulette_spin") or spin_elapsed_msec < 80 or spin_elapsed_msec > 140:
			failures.append("Roulette long-run Web spin did not begin at its authored surface time: %dms." % spin_elapsed_msec)
		spin_canvas.free()
	var early_recent_numbers: Array = _baccarat_dictionary_array(early_result_surface.get("recent_numbers", []))
	if not early_recent_numbers.is_empty():
		failures.append("Roulette recent-number strip revealed a spin before the result animation settled.")
	var early_last_results: Array = _baccarat_dictionary_array(early_result_surface.get("last_results", []))
	if not early_last_results.is_empty():
		failures.append("Roulette last_results exposed a spin before the result animation settled.")
	if not str(early_result_surface.get("result_message", "")).strip_edges().is_empty():
		failures.append("Roulette result message appeared before the result animation settled.")
	if bool(early_result_surface.get("roulette_result_settled", true)):
		failures.append("Roulette surface marked an in-flight result as settled.")
	if int(early_result_surface.get("bankroll", -999999)) != int(before.get("bankroll", -1)):
		failures.append("Roulette visible bankroll settled before the payout animation finished.")
	var payout_surface := game.surface_state(run_state, environment, {"surface_time_msec": resolved_at_msec + 5600 + 400})
	var payout_channels: Array = payout_surface.get("surface_animation_channels", []) if typeof(payout_surface.get("surface_animation_channels", [])) == TYPE_ARRAY else []
	var payout_channel: Dictionary = {}
	for channel_value in payout_channels:
		if typeof(channel_value) == TYPE_DICTIONARY and str((channel_value as Dictionary).get("id", "")) == "roulette_payout":
			payout_channel = channel_value as Dictionary
			break
	if str(payout_surface.get("phase", "")) != "payout" or str(payout_channel.get("clock_source", "")) != "surface" or str(payout_channel.get("active_id", "")).is_empty():
		failures.append("Roulette payout animation did not follow the spin on the surface clock.")
	else:
		var payout_canvas: Control = GameSurfaceCanvasScript.new()
		payout_canvas.size = Vector2(ArtContractsScript.GAME_BOARD_SIZE)
		payout_canvas.render_game_snapshot(payout_surface)
		var payout_elapsed_msec := int(round(payout_canvas.surface_elapsed("roulette_payout") * 1000.0))
		if not payout_canvas.surface_animation_active("roulette_payout") or payout_elapsed_msec < 380 or payout_elapsed_msec > 440:
			failures.append("Roulette Web payout did not start after the complete wheel spin: %dms." % payout_elapsed_msec)
		payout_canvas.free()
	var payout_draw_harness := SurfaceHarness.new()
	payout_draw_harness.setup({})
	payout_draw_harness.animation_active = true
	payout_draw_harness.animation_progress = 0.5
	game.call("_draw_payout_animation", payout_draw_harness, {
		"last_result": {
			"bet_results": [{
				"won": true,
				"bankroll_delta": 36,
				"celebration_score": 72,
				"placement": {"x": 684.0, "y": 565.0},
			}],
		},
	})
	if not payout_draw_harness.labels.has("36"):
		failures.append("Roulette payout channel did not draw the winning-chip travel animation.")
	var display_settle_msec := resolved_at_msec + 5600 + 1800 + 1600 + 1
	var display_settled_surface := game.surface_state(run_state, environment, {"surface_time_msec": display_settle_msec})
	if not bool(display_settled_surface.get("roulette_result_settled", false)):
		failures.append("Roulette surface did not mark the result settled after the animation window.")
	if int(display_settled_surface.get("bankroll", -999999)) != run_state.bankroll:
		failures.append("Roulette visible bankroll did not settle to the applied RunState bankroll after animation.")
	var result_surface := game.surface_state(run_state, environment, {})
	if str((result_surface.get("last_result", {}) as Dictionary).get("winning_number", "")) != str(result.get("roulette_winning_number", "")):
		failures.append("Roulette post-spin surface did not expose the latest winning number.")
	_check_surface_visual_motion_advances(game, result_surface, "Roulette post-payout handoff", failures)
	_check_roulette_spin_lands_on_result(game, result_surface, failures)
	var post_spin_harness := SurfaceHarness.new()
	post_spin_harness.setup(result_surface)
	post_spin_harness.animation_active = false
	game.draw_surface(post_spin_harness, result_surface, {"contract_harness": true})
	var wheel_label_numbers: Dictionary = {}
	var wheel_label_center := Vector2(150.0, 182.0)
	for label_value in post_spin_harness.label_records:
		if typeof(label_value) != TYPE_DICTIONARY:
			continue
		var label_record: Dictionary = label_value
		var text := str(label_record.get("text", ""))
		if not wheel_sequence.has(text):
			continue
		if int(label_record.get("font_size", 0)) > 7:
			continue
		var label_rect: Rect2 = label_record.get("rect", Rect2())
		var distance := label_rect.get_center().distance_to(wheel_label_center)
		if distance < 112.0 or distance > 138.0:
			continue
		wheel_label_numbers[text] = true
	if wheel_label_numbers.size() < wheel_sequence.size():
		failures.append("Roulette post-spin wheel must keep pocket numbers attached to every wheel section; saw %d of %d." % [wheel_label_numbers.size(), wheel_sequence.size()])
	var recent_numbers: Array = _baccarat_dictionary_array(result_surface.get("recent_numbers", []))
	if recent_numbers.is_empty() or str((recent_numbers[0] as Dictionary).get("number", "")) != str(result.get("roulette_winning_number", "")):
		failures.append("Roulette recent-number strip did not record the latest spin.")
	var last_result: Dictionary = result_surface.get("last_result", {}) if typeof(result_surface.get("last_result", {})) == TYPE_DICTIONARY else {}
	if int(last_result.get("celebration_score", -1)) < 0:
		failures.append("Roulette spin result did not expose proportional celebration metadata.")
	var rebet_surface := game.surface_state(run_state, environment, {})
	if not bool(rebet_surface.get("can_rebet", false)):
		failures.append("Roulette surface did not enable rebet after a completed spin.")
	var rebet_click := _check_surface_command_non_mutating(game, "roulette_rebet", 0, false, {}, run_state, environment, "roulette rebet", failures)
	var rebet_state: Dictionary = rebet_click.get("ui_state", {}) if typeof(rebet_click.get("ui_state", {})) == TYPE_DICTIONARY else {}
	var rebet_bets: Array = rebet_state.get("roulette_bets", []) as Array
	var persisted_last_bets: Array = ((environment.get("game_states", {}) as Dictionary).get("roulette", {}) as Dictionary).get("last_bets", []) as Array
	if JSON.stringify(rebet_bets) != JSON.stringify(persisted_last_bets):
		failures.append("Roulette rebet did not restore the previous layout exactly.")

	var sit_run_state: RunState = RunStateScript.new()
	sit_run_state.start_new("ROULETTE-SITOUT-CONTRACT")
	sit_run_state.bankroll = 1000
	var sit_environment := _surface_contract_environment()
	sit_environment["game_ids"] = ["roulette"]
	sit_environment["economic_profile"] = {"stake_floor": 1, "stake_ceiling": 200}
	sit_environment["game_states"] = {"roulette": table.duplicate(true)}
	sit_run_state.current_environment = sit_environment.duplicate(true)
	var sit_click := _check_surface_command_non_mutating(game, "roulette_spin", 0, false, {}, sit_run_state, sit_environment, "roulette sit-out spin", failures)
	if str(sit_click.get("action_id", "")) != "spin_roulette" or bool(sit_click.get("resolve", false)) or not bool((sit_click.get("ui_state", {}) as Dictionary).get("roulette_sit_out", false)):
		failures.append("Roulette no-bet spin did not arm a sit-out confirmation.")
	var sit_ui: Dictionary = sit_click.get("ui_state", {})
	sit_ui["selected_action_id"] = "spin_roulette"
	sit_ui["selected_action_kind"] = "legal"
	var sit_confirm := game.surface_action_command("roulette_spin", 0, false, sit_ui, sit_run_state, sit_environment)
	if not bool(sit_confirm.get("resolve", false)):
		failures.append("Roulette sit-out confirmation did not resolve on the second click.")
	var sit_before := _run_state_result_snapshot(sit_run_state)
	var sit_result := game.resolve_with_context("spin_roulette", contract_chip, sit_run_state, sit_environment, sit_run_state.create_rng("roulette_sitout_spin"), sit_confirm.get("ui_state", {}))
	_check_action_result_application_contract(sit_before, sit_run_state, sit_result, "roulette sit-out result", failures)
	if not bool(sit_result.get("roulette_sat_out", false)) or int(sit_result.get("roulette_total_wager", -1)) != 0 or int(sit_result.get("bankroll_delta", 999)) != 0:
		failures.append("Roulette sit-out spin did not resolve with zero wager and zero bankroll movement.")

	var timer_table: Dictionary = table.duplicate(true)
	timer_table["last_result"] = {}
	timer_table["table_round_timer_started_msec"] = Time.get_ticks_msec() - RouletteGame.ROULETTE_ROUND_DELAY_MSEC - 100
	var timer_environment := _surface_contract_environment()
	timer_environment["game_ids"] = ["roulette"]
	timer_environment["economic_profile"] = {"stake_floor": 1, "stake_ceiling": 200}
	timer_environment["game_states"] = {"roulette": timer_table}
	var timer_run_state: RunState = RunStateScript.new()
	timer_run_state.start_new("ROULETTE-TIMER-CONTRACT")
	timer_run_state.bankroll = 1000
	timer_run_state.current_environment = timer_environment.duplicate(true)
	if not game.surface_needs_auto_tick({"surface_time_msec": Time.get_ticks_msec()}, timer_run_state, timer_environment):
		failures.append("Roulette table timer did not request an auto sit-out spin when due.")
	var auto_spin := game.surface_auto_action_command({"surface_time_msec": Time.get_ticks_msec()}, timer_run_state, timer_environment, {})
	if str(auto_spin.get("action_id", "")) != "spin_roulette" or not bool(auto_spin.get("direct_resolve", false)) or not bool((auto_spin.get("ui_state", {}) as Dictionary).get("roulette_sit_out", false)):
		failures.append("Roulette timer auto command did not resolve a sit-out spin through the normal spin action.")

	var nudge_run_state: RunState = RunStateScript.new()
	nudge_run_state.start_new("ROULETTE-NUDGE-CONTRACT")
	nudge_run_state.bankroll = 1000
	var nudge_environment := _surface_contract_environment()
	nudge_environment["archetype_id"] = "grand_casino_high_limit"
	nudge_environment["game_ids"] = ["roulette"]
	nudge_environment["economic_profile"] = {"stake_floor": 1, "stake_ceiling": 200}
	nudge_environment["security_profile"] = {"strictness": "boss"}
	var nudge_table: Dictionary = table.duplicate(true)
	var nudge_patrons: Array = nudge_table.get("patrons", []) as Array
	for i in range(nudge_patrons.size()):
		if typeof(nudge_patrons[i]) == TYPE_DICTIONARY:
			var patron: Dictionary = nudge_patrons[i]
			patron["watching"] = true
			patron["snitch_risk"] = 60
			patron["snitch_threshold"] = 4
			nudge_patrons[i] = patron
	nudge_table["patrons"] = nudge_patrons
	nudge_environment["game_states"] = {"roulette": nudge_table}
	nudge_run_state.current_environment = nudge_environment.duplicate(true)
	nudge_run_state.grand_casino_chips = 1000
	var nudge_bet_click := game.surface_action_command("roulette_bet", straight_17_index, false, {"selected_chip": contract_chip}, nudge_run_state, nudge_environment)
	var nudge_ui: Dictionary = nudge_bet_click.get("ui_state", {})
	var nudge_click := game.surface_action_command("roulette_nudge", 0, false, nudge_ui, nudge_run_state, nudge_environment)
	nudge_ui = nudge_click.get("ui_state", {})
	var nudge_result := game.resolve_with_context("spin_roulette", contract_chip, nudge_run_state, nudge_environment, nudge_run_state.create_rng("roulette_nudge_spin"), nudge_ui)
	if not bool(nudge_result.get("roulette_wheel_nudge", false)) or str(nudge_result.get("roulette_winning_number", "")) != "17" or int(nudge_result.get("suspicion_delta", 0)) < 10:
		failures.append("Roulette nudge did not retarget a working bet and apply significant watched heat: nudge=%s number=%s suspicion=%d." % [
			str(nudge_result.get("roulette_wheel_nudge", false)),
			str(nudge_result.get("roulette_winning_number", "")),
			int(nudge_result.get("suspicion_delta", 0)),
		])

	var read_fixture := _roulette_wheel_read_fixture(game, table, "ROULETTE-READ-WHEEL-CONTRACT")
	var read_run_state := read_fixture.get("run_state", null) as RunState
	var read_environment: Dictionary = read_fixture.get("environment", {})
	var read_click: Dictionary = read_fixture.get("command", {})
	if str(read_click.get("action_id", "")) != "read_wheel_bias" or bool(read_click.get("resolve", false)):
		failures.append("Roulette read-wheel command did not stage a non-immediate cheat read.")
	var read_ui: Dictionary = read_click.get("ui_state", {})
	var read_challenge: Dictionary = read_ui.get("wheel_read_challenge", {}) if typeof(read_ui.get("wheel_read_challenge", {})) == TYPE_DICTIONARY else {}
	var read_surface := game.surface_state(read_run_state, read_environment, read_ui)
	if read_challenge.is_empty() or not bool(read_surface.get("wheel_read_active", false)) or not bool(read_surface.get("surface_realtime_state_refresh", false)):
		failures.append("Roulette read-wheel command did not expose a live timing challenge.")
	read_ui["surface_time_msec"] = int(read_challenge.get("target_msec", 0))
	var lock_read := game.surface_action_command("roulette_read_wheel", 0, false, read_ui, read_run_state, read_environment)
	if not bool(lock_read.get("resolve", false)):
		failures.append("Roulette read-wheel second input did not resolve the timing challenge.")
	var read_before := _run_state_result_snapshot(read_run_state)
	var read_result := game.resolve_with_context("read_wheel_bias", 0, read_run_state, read_environment, read_run_state.create_rng("roulette_read_wheel_resolve"), lock_read.get("ui_state", read_ui))
	_check_action_result_shape(read_result, "cheat", failures)
	_check_action_result_application_contract(read_before, read_run_state, read_result, "roulette read wheel result", failures)
	var revealed_read: Dictionary = read_result.get("roulette_bias_read", {}) if typeof(read_result.get("roulette_bias_read", {})) == TYPE_DICTIONARY else {}
	var persisted_read: Dictionary = (((read_environment.get("game_states", {}) as Dictionary).get("roulette", {}) as Dictionary).get("bias_read", {}) as Dictionary)
	if int(read_result.get("suspicion_delta", -1)) != 0 or str(read_result.get("skill_grade", "")) != "perfect" or not bool(read_result.get("roulette_wheel_read_applied", false)) or not bool(revealed_read.get("applied", false)):
		failures.append("Roulette perfect read did not reveal the table bias for zero Heat.")
	if str(revealed_read.get("id", "")) != str(wheel_bias.get("id", "")) or str(persisted_read.get("id", "")) != str(wheel_bias.get("id", "")):
		failures.append("Roulette successful read did not persist the exact hidden table bias.")
	var known_surface := game.surface_state(read_run_state, read_environment, {})
	if str(known_surface.get("table_notice", "")).find("TABLE READ:") < 0:
		failures.append("Roulette revealed table bias was not retained as visible table information.")
	var direct_fixture := _roulette_wheel_read_fixture(game, table, "ROULETTE-READ-WHEEL-DIRECT")
	var direct_run := direct_fixture.get("run_state", null) as RunState
	var direct_environment: Dictionary = direct_fixture.get("environment", {})
	var direct_command: Dictionary = direct_fixture.get("command", {})
	var direct_result := game.resolve_with_context("read_wheel_bias", 0, direct_run, direct_environment, direct_run.create_rng("roulette_read_direct"), direct_command.get("ui_state", {}))
	if str(direct_result.get("skill_grade", "")) != "miss" or bool(direct_result.get("roulette_wheel_read_applied", true)) or int(direct_result.get("suspicion_delta", 0)) != 20 or str(direct_result.get("message", "")).to_lower().find("nothing") < 0:
		failures.append("Roulette failed read did not produce no information and exactly 20 Heat.")
	var deterministic_a := _roulette_wheel_read_fixture(game, table, "ROULETTE-READ-DETERMINISTIC")
	var deterministic_b := _roulette_wheel_read_fixture(game, table, "ROULETTE-READ-DETERMINISTIC")
	if JSON.stringify(deterministic_a.get("challenge", {})) != JSON.stringify(deterministic_b.get("challenge", {})):
		failures.append("Roulette read-wheel challenge was not deterministic for the same seed and input.")
	var sober_read := _roulette_wheel_read_fixture(game, table, "ROULETTE-READ-MODIFIERS")
	var drunk_read := _roulette_wheel_read_fixture(game, table, "ROULETTE-READ-MODIFIERS", 85)
	var item_read := _roulette_wheel_read_fixture(game, table, "ROULETTE-READ-MODIFIERS", 0, "chip_slide_wax")
	if int((drunk_read.get("challenge", {}) as Dictionary).get("perfect_window_msec", 999)) >= int((sober_read.get("challenge", {}) as Dictionary).get("perfect_window_msec", 0)):
		failures.append("Roulette alcohol did not narrow the read-wheel precision window.")
	if int((item_read.get("challenge", {}) as Dictionary).get("perfect_window_msec", 0)) <= int((sober_read.get("challenge", {}) as Dictionary).get("perfect_window_msec", 0)):
		failures.append("Roulette chip-slide contraband did not sharpen the read-wheel input.")
	if int((item_read.get("challenge", {}) as Dictionary).get("base_heat", 0)) != 20 or int((sober_read.get("challenge", {}) as Dictionary).get("base_heat", 0)) != 20:
		failures.append("Roulette read-wheel failure risk did not remain fixed at 20 Heat.")
	_check_roulette_wheel_bias_contract(game, table, failures)

	_check_roulette_past_post_contract(game, library, failures)
	if library != null:
		_check_premium_grand_casino_table_contract(library, "roulette", game, failures)
	_check_roulette_payout_contract(game, table, failures)


func _roulette_wheel_read_fixture(game: GameModule, table: Dictionary, seed_text: String, drunk_level: int = 0, item_id: String = "") -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed_text)
	run_state.bankroll = 1000
	run_state.drunk_level = drunk_level
	if not item_id.is_empty():
		run_state.add_item(item_id)
	var environment := _surface_contract_environment()
	environment["game_ids"] = ["roulette"]
	environment["economic_profile"] = {"stake_floor": 1, "stake_ceiling": 200}
	environment["game_states"] = {"roulette": table.duplicate(true)}
	run_state.current_environment = environment.duplicate(true)
	var command := game.surface_action_command("roulette_read_wheel", 0, false, {"surface_time_msec": 12000}, run_state, environment)
	var ui: Dictionary = command.get("ui_state", {})
	return {"run_state": run_state, "environment": environment, "command": command, "challenge": ui.get("wheel_read_challenge", {})}


func _check_roulette_wheel_bias_contract(game: GameModule, base_table: Dictionary, failures: Array) -> void:
	var skew_table := base_table.duplicate(true)
	skew_table["wheel_bias"] = {
		"id": "color_red",
		"type": "outside_skew",
		"axis": "color",
		"favored_bet": "red",
		"favored_label": "RED",
		"opposed_bet": "black",
		"opposed_label": "BLACK",
		"favored_percent": 60,
	}
	var skew_rng := RngStream.new()
	skew_rng.configure(731991)
	var red_count := 0
	var black_count := 0
	var green_count := 0
	for _spin_index in range(6000):
		var number := str(game.call("_sample_biased_winning_number", skew_table, skew_table.get("wheel_bias", {}), skew_rng))
		if ["0", "00"].has(number):
			green_count += 1
		elif (base_table.get("red_numbers", []) as Array).has(number):
			red_count += 1
		else:
			black_count += 1
	var non_green := red_count + black_count
	var red_share := float(red_count) / float(maxi(1, non_green))
	var normal_green_share := float(green_count) / 6000.0
	if red_share < 0.57 or red_share > 0.63:
		failures.append("Roulette red table bias did not converge on a 60/40 non-green split: %.3f." % red_share)
	if normal_green_share < 0.035 or normal_green_share > 0.075:
		failures.append("Roulette outside skew changed the normal green-pocket share: %.3f." % normal_green_share)

	var magnet_table := base_table.duplicate(true)
	magnet_table["wheel_bias"] = {"id": "green_magnet", "type": "green_magnet", "favored_bet": "green", "favored_label": "GREEN", "green_multiplier": 2}
	var magnet_rng := RngStream.new()
	magnet_rng.configure(731991)
	var magnet_green_count := 0
	for _spin_index in range(6000):
		var magnet_number := str(game.call("_sample_biased_winning_number", magnet_table, magnet_table.get("wheel_bias", {}), magnet_rng))
		if ["0", "00"].has(magnet_number):
			magnet_green_count += 1
	var magnet_green_share := float(magnet_green_count) / 6000.0
	if magnet_green_share < 0.08 or magnet_green_share > 0.12 or magnet_green_share <= normal_green_share * 1.6:
		failures.append("Roulette green magnet did not double green-pocket outcome weight: %.3f versus %.3f." % [magnet_green_share, normal_green_share])

	skew_table["bias_read"] = {"applied": true, "id": "color_red"}
	skew_table["bias_exploit_wins"] = 0
	var red_bet := {
		"type": "red",
		"numbers": (base_table.get("red_numbers", []) as Array).duplicate(true),
		"stake": 10,
		"payout": 1,
	}
	var exploit_heats: Array = []
	for _win_index in range(5):
		var exploit: Dictionary = game.call("_record_revealed_bias_exploitation", skew_table, [red_bet], "1")
		exploit_heats.append(int(exploit.get("heat", -1)))
	if exploit_heats != [0, 2, 4, 8, 16]:
		failures.append("Roulette repeated skew wins did not add exponential Heat: %s." % str(exploit_heats))
	var wins_before_wrong_side := int(skew_table.get("bias_exploit_wins", 0))
	var wrong_side: Dictionary = game.call("_record_revealed_bias_exploitation", skew_table, [red_bet], "2")
	if not wrong_side.is_empty() or int(skew_table.get("bias_exploit_wins", 0)) != wins_before_wrong_side:
		failures.append("Roulette skew exploitation advanced when the revealed favored outcome did not win.")
	var hidden_table := skew_table.duplicate(true)
	hidden_table["bias_read"] = {}
	hidden_table["bias_exploit_wins"] = 0
	if not (game.call("_record_revealed_bias_exploitation", hidden_table, [red_bet], "1") as Dictionary).is_empty():
		failures.append("Roulette charged exploitation Heat before the player learned the table bias.")

	var legacy_table := base_table.duplicate(true)
	legacy_table.erase("wheel_bias")
	legacy_table["normalized_version"] = 1
	var normalized_legacy: Dictionary = game.call("_normalize_table_state", legacy_table)
	if int(normalized_legacy.get("normalized_version", 0)) < 2 or (normalized_legacy.get("wheel_bias", {}) as Dictionary).is_empty():
		failures.append("Roulette legacy table normalization did not add a deterministic persistent bias.")


func _check_roulette_past_post_contract(game: GameModule, library: ContentLibrary, failures: Array) -> void:
	var window_fixture := _roulette_past_post_fixture(game, "ROULETTE-PAST-WINDOW", 10)
	var window_run := window_fixture.get("run_state", null) as RunState
	if window_run == null:
		failures.append("Roulette past-post fixture did not return a RunState.")
		return
	var window_environment: Dictionary = window_run.current_environment
	var payout_ui: Dictionary = window_fixture.get("payout_ui", {})
	var payout_surface := game.surface_state(window_run, window_environment, payout_ui)
	if str(payout_surface.get("phase", "")) != "payout" or not bool(payout_surface.get("past_post_available", false)):
		failures.append("Roulette past-post window did not open during the payout animation.")
	var payout_harness := SurfaceHarness.new()
	payout_harness.setup(payout_surface)
	game.draw_surface(payout_harness, payout_surface, {"contract_harness": true})
	if not _surface_harness_has_action(payout_harness, "roulette_past_post"):
		failures.append("Roulette payout surface did not expose the past-post action.")
	if _surface_blocks_action(payout_surface, "roulette_past_post"):
		failures.append("Roulette payout surface blocked the past-post action during its own window.")
	if not _surface_blocks_action(payout_surface, "roulette_bet"):
		failures.append("Roulette payout surface did not keep ordinary betting blocked.")
	var armed_command := _check_surface_command_non_mutating(game, "roulette_past_post", 0, false, payout_ui, window_run, window_environment, "roulette past-post arm", failures)
	var armed_ui: Dictionary = armed_command.get("ui_state", {})
	if str(armed_command.get("action_id", "")) != "past_post" or bool(armed_command.get("resolve", false)):
		failures.append("Roulette first past-post click did not arm the cheat challenge.")
	var challenge: Dictionary = armed_ui.get("past_post_challenge", {}) if typeof(armed_ui.get("past_post_challenge", {})) == TYPE_DICTIONARY else {}
	if challenge.is_empty():
		failures.append("Roulette past-post arm did not create a timing challenge.")
	else:
		armed_ui["past_post_input_msec"] = int(challenge.get("window_start_msec", 0))
		armed_ui["surface_time_msec"] = int(challenge.get("window_start_msec", 0))
		var confirmed := _check_surface_command_non_mutating(game, "roulette_past_post", 0, false, armed_ui, window_run, window_environment, "roulette past-post confirm", failures)
		if not bool(confirmed.get("resolve", false)):
			failures.append("Roulette second past-post click did not resolve the timed cheat.")
	var round_trip_ui: Dictionary = JSON.parse_string(JSON.stringify(armed_ui))
	var round_trip_surface := game.surface_state(window_run, window_environment, round_trip_ui)
	if typeof(round_trip_surface.get("past_post_challenge", {})) != TYPE_DICTIONARY or (round_trip_surface.get("past_post_challenge", {}) as Dictionary).is_empty():
		failures.append("Roulette past-post UI state did not survive save/load-style serialization mid-challenge.")

	var perfect := _roulette_past_post_result(game, "ROULETTE-PAST-PERFECT", 0, false, library)
	var perfect_result: Dictionary = perfect.get("result", {})
	if str(perfect_result.get("skill_grade", "")) != "perfect" or not bool(perfect_result.get("roulette_past_post_applied", false)) or int(perfect_result.get("bankroll_delta", 0)) <= 0:
		failures.append("Roulette perfect past-post did not apply a positive graded late-chip payoff.")
	_check_action_result_shape(perfect_result, "cheat", failures)
	var perfect_before: Dictionary = perfect.get("before", {})
	var perfect_run := perfect.get("run_state", null) as RunState
	if perfect_run != null:
		_check_action_result_application_contract(perfect_before, perfect_run, perfect_result, "roulette perfect past-post result", failures)

	var good_result: Dictionary = _roulette_past_post_result(game, "ROULETTE-PAST-GOOD", 180, false, library).get("result", {})
	if str(good_result.get("skill_grade", "")) != "good" or int(good_result.get("roulette_past_post_payout_mult", 0)) > 17:
		failures.append("Roulette good past-post did not report the capped good timing grade.")
	var partial_result: Dictionary = _roulette_past_post_result(game, "ROULETTE-PAST-PARTIAL", 520, false, library).get("result", {})
	if str(partial_result.get("skill_grade", "")) != "partial" or int(partial_result.get("roulette_past_post_payout_mult", -1)) != 1:
		failures.append("Roulette partial past-post did not fall back to an outside-cover payoff.")
	var blown := _roulette_past_post_result(game, "ROULETTE-PAST-BLOWN", 900, false, library)
	var blown_result: Dictionary = blown.get("result", {})
	if str(blown_result.get("skill_grade", "")) != "blown" or int(blown_result.get("bankroll_delta", 0)) >= 0 or int(blown_result.get("suspicion_delta", 0)) <= int(partial_result.get("suspicion_delta", 0)):
		failures.append("Roulette blown past-post did not void the chip and raise extra heat.")
	var blown_run := blown.get("run_state", null) as RunState
	if blown_run != null:
		var repeat_result := game.resolve_with_context("past_post", 5, blown_run, blown_run.current_environment, blown_run.create_rng("roulette_past_repeat"), blown.get("ui_state", {}))
		if bool(repeat_result.get("ok", false)):
			failures.append("Roulette past-post could be repeated against the same settled spin.")

	var late_fixture := _roulette_past_post_fixture(game, "ROULETTE-PAST-LATE", 5)
	var late_run := late_fixture.get("run_state", null) as RunState
	if late_run != null:
		var late_ui: Dictionary = late_fixture.get("payout_ui", {})
		late_ui["surface_time_msec"] = int(late_ui.get("surface_time_msec", 0)) + 2200
		var late_bankroll := late_run.bankroll
		var late_command := game.surface_action_command("roulette_past_post", 0, false, late_ui, late_run, late_run.current_environment)
		if bool(late_command.get("resolve", false)) or late_run.bankroll != late_bankroll:
			failures.append("Roulette late past-post input altered an already-paid result.")

	var clean_run: RunState = RunStateScript.new()
	clean_run.start_new("ROULETTE-CLEAN-EVIDENCE")
	clean_run.bankroll = 100000
	var clean_environment := _surface_contract_environment()
	clean_environment["archetype_id"] = "grand_casino_high_limit"
	clean_environment["kind"] = "boss"
	clean_environment["game_ids"] = ["roulette"]
	clean_environment["game_states"] = {"roulette": game.generate_environment_state(clean_run, clean_environment, clean_run.create_rng("roulette_clean_state"))}
	clean_run.set_environment(clean_environment)
	clean_run.grand_casino_chips = 1000
	var clean_result := game.resolve_with_context("spin_roulette", 10, clean_run, clean_run.current_environment, clean_run.create_rng("roulette_clean_spin"), {"roulette_bets": [game.call("_default_smoke_bet", 10)]})
	if str(clean_result.get("action_kind", "")) != "legal" or bool(clean_result.get("skill_cheat_contract", false)) or bool(clean_run.narrative_flags.get("grand_casino_cheat_evidence", false)):
		failures.append("Roulette clean spin left open-cheat evidence: action_kind=%s skill_contract=%s evidence=%s." % [
			str(clean_result.get("action_kind", "")),
			str(clean_result.get("skill_cheat_contract", false)),
			str(clean_run.narrative_flags.get("grand_casino_cheat_evidence", false)),
		])

	if library != null:
		var boss_archetype := _archetype_by_id(library, "grand_casino_high_limit")
		if boss_archetype.is_empty():
			failures.append("Roulette past-post Grand Casino fixture requires the grand_casino_high_limit archetype.")
		else:
			var grand := _roulette_past_post_result(game, "ROULETTE-PAST-GRAND", 900, true, library)
			var grand_result: Dictionary = grand.get("result", {})
			var grand_run := grand.get("run_state", null) as RunState
			if grand_run == null:
				failures.append("Roulette Grand Casino past-post fixture did not return a RunState.")
			else:
				var grand_status := grand_run.demo_objective_status()
				if not bool(grand_result.get("pit_boss_watched", false)) or int(grand_result.get("pit_boss_heat_bonus", 0)) <= 0:
					failures.append("Roulette caught Grand Casino past-post did not mark watched staff pressure.")
				if not bool(grand_run.narrative_flags.get("grand_casino_attention_watched_cheat", false)) or not bool(grand_status.get("staff_attention_active", false)):
					failures.append("Roulette caught Grand Casino past-post did not mark staff attention.")
				if not bool(grand_status.get("showdown_pending", false)) and not bool(grand_status.get("showdown_active", false)):
					failures.append("Roulette caught Grand Casino past-post did not feed showdown pressure.")


func _roulette_past_post_result(game: GameModule, seed_text: String, margin_msec: int, grand_casino: bool, library: ContentLibrary) -> Dictionary:
	var fixture := _roulette_past_post_fixture(game, seed_text, 5, grand_casino, library)
	var run_state := fixture.get("run_state", null) as RunState
	if run_state == null:
		return {}
	var ui: Dictionary = fixture.get("payout_ui", {})
	var arm_command: Dictionary = game.surface_action_command("roulette_past_post", 0, false, ui, run_state, run_state.current_environment)
	var arm_ui: Dictionary = arm_command.get("ui_state", ui)
	var challenge: Dictionary = arm_ui.get("past_post_challenge", {}) if typeof(arm_ui.get("past_post_challenge", {})) == TYPE_DICTIONARY else {}
	var input_msec := int(challenge.get("window_start_msec", int(ui.get("surface_time_msec", 0)))) + margin_msec
	arm_ui["surface_time_msec"] = input_msec
	arm_ui["past_post_input_msec"] = input_msec
	arm_ui["selected_action_id"] = "past_post"
	arm_ui["selected_action_kind"] = "cheat"
	var confirm_command: Dictionary = game.surface_action_command("roulette_past_post", 0, false, arm_ui, run_state, run_state.current_environment)
	var resolve_ui: Dictionary = confirm_command.get("ui_state", arm_ui)
	var before := _run_state_result_snapshot(run_state)
	var result := game.resolve_with_context("past_post", 5, run_state, run_state.current_environment, run_state.create_rng("%s_resolve" % seed_text.to_lower()), resolve_ui)
	return {
		"run_state": run_state,
		"ui_state": resolve_ui,
		"before": before,
		"result": result,
	}


func _roulette_past_post_fixture(game: GameModule, seed_text: String, chip: int, grand_casino: bool = false, library: ContentLibrary = null) -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed_text)
	run_state.bankroll = 100000
	var environment := _surface_contract_environment()
	if grand_casino and library != null:
		var boss_archetype := _archetype_by_id(library, "grand_casino")
		if not boss_archetype.is_empty():
			run_state = _grand_casino_game_fixture_run(library, boss_archetype, "roulette", game, seed_text)
			var objective: Dictionary = boss_archetype.get("demo_objective", {}) if typeof(boss_archetype.get("demo_objective", {})) == TYPE_DICTIONARY else {}
			var showdown_threshold := clampi(int(objective.get("showdown_heat_threshold", 70)), 1, 100)
			run_state.add_suspicion("%s_preheat" % seed_text.to_lower(), maxi(0, showdown_threshold - 1), "behavior")
			environment = run_state.current_environment
	environment["archetype_id"] = "grand_casino" if grand_casino else str(environment.get("archetype_id", "surface_contract_room"))
	environment["kind"] = "boss" if grand_casino else str(environment.get("kind", "casino"))
	environment["game_ids"] = ["roulette"]
	environment["economic_profile"] = {"stake_floor": 1, "stake_ceiling": 200}
	environment["security_profile"] = {"strictness": "boss", "pit_boss": {"enabled": true, "cycle_length": 1, "watched_turns": 1, "cheat_heat_bonus": 20}} if grand_casino else {"strictness": "low"}
	var game_states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var table: Dictionary = game_states.get("roulette", {}) if typeof(game_states.get("roulette", {})) == TYPE_DICTIONARY else {}
	if table.is_empty():
		table = game.generate_environment_state(run_state, environment, run_state.create_rng("%s_state" % seed_text.to_lower()))
	if grand_casino:
		var patrons: Array = table.get("patrons", []) if typeof(table.get("patrons", [])) == TYPE_ARRAY else []
		for i in range(patrons.size()):
			if typeof(patrons[i]) == TYPE_DICTIONARY:
				var patron: Dictionary = patrons[i]
				patron["watching"] = true
				patron["snitch_risk"] = 70
				patron["snitch_threshold"] = 1
				patrons[i] = patron
		table["patrons"] = patrons
	game_states["roulette"] = table
	environment["game_states"] = game_states
	run_state.set_environment(environment)
	var spin_ui := {"roulette_bets": [game.call("_default_smoke_bet", chip)], "selected_chip": chip}
	var spin_result := game.resolve_with_context("spin_roulette", chip, run_state, run_state.current_environment, run_state.create_rng("%s_spin" % seed_text.to_lower()), spin_ui)
	var spun_table: Dictionary = ((run_state.current_environment.get("game_states", {}) as Dictionary).get("roulette", {}) as Dictionary)
	var last_result: Dictionary = spun_table.get("last_result", {}) if typeof(spun_table.get("last_result", {})) == TYPE_DICTIONARY else {}
	var payout_ui := {
		"selected_chip": chip,
		"surface_time_msec": int(last_result.get("resolved_at_msec", 0)) + 5600 + 10,
	}
	return {
		"run_state": run_state,
		"spin_result": spin_result,
		"payout_ui": payout_ui,
	}


func _roulette_targets_include_type(targets: Array, target_type: String) -> bool:
	for target_value in targets:
		if typeof(target_value) == TYPE_DICTIONARY and str((target_value as Dictionary).get("type", "")) == target_type:
			return true
	return false


func _roulette_target_index(targets: Array, target_type: String, number: String) -> int:
	for i in range(targets.size()):
		if typeof(targets[i]) != TYPE_DICTIONARY:
			continue
		var target: Dictionary = targets[i]
		if str(target.get("type", "")) != target_type:
			continue
		if _string_array(target.get("numbers", [])).has(number):
			return i
	return -1


func _check_roulette_payout_contract(game: GameModule, table: Dictionary, failures: Array) -> void:
	var payout_cases := [
		{"name": "straight", "win": "17", "bet": {"id": "straight_17", "type": "straight", "label": "17", "numbers": ["17"], "stake": 2, "payout": 35, "family": "inside"}, "delta": 70},
		{"name": "split", "win": "17", "bet": {"id": "split_17_20", "type": "split", "label": "17/20", "numbers": ["17", "20"], "stake": 2, "payout": 17, "family": "inside"}, "delta": 34},
		{"name": "street", "win": "17", "bet": {"id": "street_16_18", "type": "street", "label": "16-18", "numbers": ["16", "17", "18"], "stake": 2, "payout": 11, "family": "inside"}, "delta": 22},
		{"name": "corner", "win": "17", "bet": {"id": "corner_14_18", "type": "corner", "label": "14/15/17/18", "numbers": ["14", "15", "17", "18"], "stake": 2, "payout": 8, "family": "inside"}, "delta": 16},
		{"name": "six_line", "win": "17", "bet": {"id": "six_13_18", "type": "six_line", "label": "13-18", "numbers": ["13", "14", "15", "16", "17", "18"], "stake": 2, "payout": 5, "family": "inside"}, "delta": 10},
		{"name": "trio", "win": "2", "bet": {"id": "trio_0_1_2", "type": "trio", "label": "0/1/2", "numbers": ["0", "1", "2"], "stake": 2, "payout": 11, "family": "inside"}, "delta": 22},
		{"name": "top_line", "win": "2", "bet": {"id": "top_line", "type": "top_line", "label": "0/00/1/2/3", "numbers": ["0", "00", "1", "2", "3"], "stake": 2, "payout": 6, "family": "inside"}, "delta": 12},
		{"name": "dozen", "win": "17", "bet": {"id": "dozen_13_24", "type": "dozen", "label": "2nd 12", "numbers": _range_int_strings(13, 24), "stake": 2, "payout": 2, "family": "outside"}, "delta": 4},
		{"name": "column", "win": "17", "bet": {"id": "column_2", "type": "column", "label": "2 TO 1", "numbers": ["2", "5", "8", "11", "14", "17", "20", "23", "26", "29", "32", "35"], "stake": 2, "payout": 2, "family": "outside"}, "delta": 4},
		{"name": "black", "win": "17", "bet": {"id": "black", "type": "black", "label": "BLACK", "numbers": ["2", "4", "6", "8", "10", "11", "13", "15", "17", "20", "22", "24", "26", "28", "29", "31", "33", "35"], "stake": 2, "payout": 1, "family": "outside"}, "delta": 2},
		{"name": "red loss", "win": "17", "bet": {"id": "red", "type": "red", "label": "RED", "numbers": ["1", "3", "5", "7", "9", "12", "14", "16", "18", "19", "21", "23", "25", "27", "30", "32", "34", "36"], "stake": 2, "payout": 1, "family": "outside"}, "delta": -2},
		{"name": "odd", "win": "17", "bet": {"id": "odd", "type": "odd", "label": "ODD", "numbers": _range_odd_int_strings(), "stake": 2, "payout": 1, "family": "outside"}, "delta": 2},
		{"name": "even", "win": "18", "bet": {"id": "even", "type": "even", "label": "EVEN", "numbers": _range_even_int_strings(), "stake": 2, "payout": 1, "family": "outside"}, "delta": 2},
		{"name": "low", "win": "17", "bet": {"id": "low", "type": "low", "label": "1-18", "numbers": _range_int_strings(1, 18), "stake": 2, "payout": 1, "family": "outside"}, "delta": 2},
		{"name": "high", "win": "20", "bet": {"id": "high", "type": "high", "label": "19-36", "numbers": _range_int_strings(19, 36), "stake": 2, "payout": 1, "family": "outside"}, "delta": 2},
	]
	for case_value in payout_cases:
		var payout_case: Dictionary = case_value
		var settled: Array = game.call("_settle_roulette_bets", str(payout_case.get("win", "")), [payout_case.get("bet", {})], table)
		if settled.is_empty() or int((settled[0] as Dictionary).get("bankroll_delta", 999999)) != int(payout_case.get("delta", 0)):
			failures.append("Roulette payout for %s was %d, expected %d." % [str(payout_case.get("name", "")), int((settled[0] as Dictionary).get("bankroll_delta", 0)) if not settled.is_empty() else 999999, int(payout_case.get("delta", 0))])
		if not settled.is_empty() and int(payout_case.get("delta", 0)) > 0 and int((settled[0] as Dictionary).get("celebration_score", 0)) <= 0:
			failures.append("Roulette winning payout for %s did not expose celebration metadata." % str(payout_case.get("name", "")))
	var red_bet: Dictionary = (payout_cases[10] as Dictionary).get("bet", {})
	var zero_loss: Array = game.call("_settle_roulette_bets", "0", [red_bet], table)
	if zero_loss.is_empty() or int((zero_loss[0] as Dictionary).get("bankroll_delta", 0)) != -2:
		failures.append("Roulette zero did not take a standard even-money outside bet.")
	var partage_table := table.duplicate(true)
	var partage_rules: Dictionary = table.get("rules", {}) if typeof(table.get("rules", {})) == TYPE_DICTIONARY else {}
	partage_rules = partage_rules.duplicate(true)
	partage_rules["la_partage"] = true
	partage_table["rules"] = partage_rules
	var partage_bet := red_bet.duplicate(true)
	partage_bet["id"] = "red_half"
	partage_bet["stake"] = 4
	var partage_loss: Array = game.call("_settle_roulette_bets", "0", [partage_bet], partage_table)
	if partage_loss.is_empty() or int((partage_loss[0] as Dictionary).get("bankroll_delta", 0)) != -2:
		failures.append("Roulette La Partage rule did not halve an even-money zero loss.")


func _range_int_strings(first: int, last: int) -> Array:
	var result: Array = []
	for value in range(first, last + 1):
		result.append(str(value))
	return result


func _range_even_int_strings() -> Array:
	var result: Array = []
	for value in range(2, 37, 2):
		result.append(str(value))
	return result


func _range_odd_int_strings() -> Array:
	var result: Array = []
	for value in range(1, 36, 2):
		result.append(str(value))
	return result


func _check_baccarat_surface_contract(game: GameModule, failures: Array, library: ContentLibrary = null) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("BACCARAT-SURFACE-CONTRACT")
	run_state.bankroll = 1000
	var environment := _surface_contract_environment()
	environment["game_ids"] = ["baccarat"]
	environment["economic_profile"] = {"stake_floor": 20, "stake_ceiling": 200}
	var table: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("baccarat_contract_table"))
	if table.is_empty():
		failures.append("Baccarat did not generate table state for an environment.")
		return
	if str(table.get("schema", "")) != "baccarat_table_state":
		failures.append("Baccarat generated table state did not expose the baccarat schema.")
	if int(table.get("deck_count", 0)) != 8:
		failures.append("Baccarat did not generate an eight-deck default shoe.")
	if (table.get("shoe", []) as Array).size() <= 0:
		failures.append("Baccarat generated an empty shoe.")
	if _baccarat_dictionary_array(table.get("patrons", [])).is_empty():
		failures.append("Baccarat generated table did not include other table players.")
	if not (table.get("dealer_profile", {}) is Dictionary) or (table.get("dealer_profile", {}) as Dictionary).is_empty():
		failures.append("Baccarat generated table did not include a croupier profile.")
	var rules: Dictionary = table.get("rules", {}) if typeof(table.get("rules", {})) == TYPE_DICTIONARY else {}
	for key in ["banker_commission_rate", "tie_payout", "player_pair_payout", "banker_pair_payout", "optional_side_bet_hooks"]:
		if not rules.has(key):
			failures.append("Baccarat rules missing required field: %s." % key)
	if str(rules.get("variant", "")) != "mini_baccarat" or not is_equal_approx(float(rules.get("banker_commission_rate", 0.0)), 0.05):
		failures.append("Baccarat rules did not explicitly choose 5% commission mini-baccarat.")
	if str(rules.get("banker_commission_rounding", "")) != "ceil_whole_unit":
		failures.append("Baccarat Banker commission rounding was not explicit.")
	environment["game_states"] = {"baccarat": table}
	run_state.current_environment = environment.duplicate(true)

	var surface := game.surface_state(run_state, environment, {})
	if str(surface.get("surface_renderer", "")) != "baccarat":
		failures.append("Baccarat surface did not route to the baccarat renderer.")
	_check_idle_animation_liveness_contract(surface, "Baccarat betting surface", failures)
	if str(surface.get("surface_life", "")) != "immersive_table" or str(surface.get("surface_cast", "")) != "dealer_table":
		failures.append("Baccarat surface did not expose immersive dealer-table metadata.")
	if not bool(surface.get("surface_controls_native", false)):
		failures.append("Baccarat surface did not expose native table controls.")
	var baccarat_round_timer: Dictionary = surface.get("table_round_timer", {}) if typeof(surface.get("table_round_timer", {})) == TYPE_DICTIONARY else {}
	if baccarat_round_timer.is_empty():
		failures.append("Baccarat betting surface did not expose realtime table-round timer state.")
	if bool(surface.get("surface_realtime_state_refresh", false)):
		failures.append("Baccarat static betting surface should not request full snapshot refreshes.")
	if not bool(surface.get("surface_animates_idle", false)):
		failures.append("Baccarat betting surface must declare idle animation liveness for dealer, patron, and timer motion.")
	var guide_explainer: Dictionary = surface.get("baccarat_explainer", {}) if typeof(surface.get("baccarat_explainer", {})) == TYPE_DICTIONARY else {}
	if str(guide_explainer.get("mode", "")) != "guide" or str(guide_explainer.get("primary", "")).find("Bet Player") < 0:
		failures.append("Baccarat betting surface did not expose a beginner-readable guide explainer.")
	var targets := _baccarat_dictionary_array(surface.get("bet_targets", []))
	for target_id in ["player", "banker", "tie", "player_pair", "banker_pair"]:
		if _baccarat_target_index(targets, target_id) < 0:
			failures.append("Baccarat betting layout missing target: %s." % target_id)
	var initial_road: Dictionary = surface.get("baccarat_road", {}) if typeof(surface.get("baccarat_road", {})) == TYPE_DICTIONARY else {}
	if str(initial_road.get("type", "")) != "bead_plate" or int(initial_road.get("rows", 0)) <= 0:
		failures.append("Baccarat surface did not expose a bead-plate road state.")
	var initial_penetration: Dictionary = surface.get("shoe_penetration", {}) if typeof(surface.get("shoe_penetration", {})) == TYPE_DICTIONARY else {}
	if int(initial_penetration.get("total_cards", 0)) < 416 or int(initial_penetration.get("remaining", 0)) <= 0:
		failures.append("Baccarat surface did not expose visible shoe penetration state.")
	var harness := SurfaceHarness.new()
	harness.setup(surface)
	harness.record_draw_rects = true
	var surface_before_draw := JSON.stringify(surface)
	if not bool(game.draw_surface(harness, surface, {"contract_harness": true})):
		failures.append("Baccarat draw_surface returned false.")
	if JSON.stringify(surface) != surface_before_draw:
		failures.append("Baccarat draw_surface mutated its authoritative source snapshot while borrowing render-only views.")
	var repeat_harness := SurfaceHarness.new()
	repeat_harness.setup(surface)
	repeat_harness.record_draw_rects = true
	game.draw_surface(repeat_harness, surface, {"contract_harness": true})
	# Dealer focus intentionally samples wall-clock time for gaze/status animation,
	# so exact text, colors, and coordinates may differ between consecutive draws.
	# The invariant contract is command structure and interaction order.
	var first_hit_order: Array = []
	var repeat_hit_order: Array = []
	for hit_value in harness.hit_regions:
		var hit: Dictionary = hit_value
		first_hit_order.append([str(hit.get("action", "")), int(hit.get("index", -1))])
	for hit_value in repeat_harness.hit_regions:
		var hit: Dictionary = hit_value
		repeat_hit_order.append([str(hit.get("action", "")), int(hit.get("index", -1))])
	var first_draw_shape: Array = []
	var repeat_draw_shape: Array = []
	for draw_value in harness.draw_rect_records:
		var draw: Dictionary = draw_value
		first_draw_shape.append([bool(draw.get("filled", true)), float(draw.get("width", -1.0))])
	for draw_value in repeat_harness.draw_rect_records:
		var draw: Dictionary = draw_value
		repeat_draw_shape.append([bool(draw.get("filled", true)), float(draw.get("width", -1.0))])
	var first_label_slots: Array = []
	var repeat_label_slots: Array = []
	for label_value in harness.label_records:
		first_label_slots.append(int((label_value as Dictionary).get("font_size", 0)))
	for label_value in repeat_harness.label_records:
		repeat_label_slots.append(int((label_value as Dictionary).get("font_size", 0)))
	if JSON.stringify(repeat_hit_order) != JSON.stringify(first_hit_order) \
			or JSON.stringify(repeat_draw_shape) != JSON.stringify(first_draw_shape) \
			or JSON.stringify(repeat_label_slots) != JSON.stringify(first_label_slots):
		failures.append("Baccarat repeated draw changed interaction order or structural draw/label command slots.")
	var found_bead_plate_label := false
	for label_value in harness.labels:
		if str(label_value).find("BEAD PLATE") >= 0:
			found_bead_plate_label = true
	if not found_bead_plate_label:
		failures.append("Baccarat renderer did not draw the bead-plate road panel.")
	if _surface_hit_count(harness, "baccarat_bet") < 5:
		failures.append("Baccarat renderer did not create hit regions for all core bet targets.")
	var player_index := _baccarat_target_index(targets, "player")
	var baccarat_bet_hit := _surface_harness_first_hit(harness, "baccarat_bet", player_index)
	_check_canvas_hit_dispatch(surface, baccarat_bet_hit.get("rect", Rect2()), "baccarat_bet", player_index, "Baccarat player-bet canvas dispatch", failures)
	for action_id in ["baccarat_chip", "baccarat_read_shoe"]:
		if not _surface_harness_has_action(harness, action_id):
			failures.append("Baccarat renderer missing surface action: %s." % action_id)
	var audio: Dictionary = surface.get("surface_audio", {}) if typeof(surface.get("surface_audio", {})) == TYPE_DICTIONARY else {}
	var sync: Dictionary = audio.get("state_sync", {}) if typeof(audio.get("state_sync", {})) == TYPE_DICTIONARY else {}
	if str(audio.get("profile_id", "")) != "baccarat_table" or str(sync.get("method", "")) != "baccarat_table_state":
		failures.append("Baccarat surface audio did not expose baccarat_table profile/sync metadata.")
	if not _surface_blocks_action_while(surface, "baccarat_bet", "baccarat_deal") or not _surface_blocks_action_while(surface, "baccarat_deal", "baccarat_deal"):
		failures.append("Baccarat surface did not block betting/dealing during the deal animation.")

	var bet_click := _check_surface_command_non_mutating(game, "baccarat_bet", player_index, false, {"selected_chip": 20}, run_state, environment, "baccarat player bet", failures)
	var bet_ui: Dictionary = bet_click.get("ui_state", {})
	if int((bet_ui.get("baccarat_bets", {}) as Dictionary).get("player", 0)) != 20:
		failures.append("Baccarat player bet did not create a $20 wager.")
	if game.wager_cost_for_context("deal_baccarat", 20, run_state, environment, bet_ui) != 20:
		failures.append("Baccarat wager cost did not reflect chips placed on the layout.")
	var ready_surface := game.surface_state(run_state, environment, bet_ui)
	if not bool(ready_surface.get("can_deal", false)):
		failures.append("Baccarat surface did not become deal-ready after a valid bet.")
	var ready_harness := SurfaceHarness.new()
	ready_harness.setup(ready_surface)
	game.draw_surface(ready_harness, ready_surface, {"contract_harness": true})
	for action_id in ["baccarat_deal", "baccarat_clear"]:
		if not _surface_harness_has_action(ready_harness, action_id):
			failures.append("Baccarat deal-ready renderer missing surface action: %s." % action_id)
	var deal_click := _check_surface_command_non_mutating(game, "baccarat_deal", 0, false, bet_ui, run_state, environment, "baccarat deal command", failures)
	if str(deal_click.get("action_id", "")) != "deal_baccarat" or not bool(deal_click.get("resolve", false)):
		failures.append("Baccarat deal command did not resolve through the legal baccarat action.")
	var before := _run_state_result_snapshot(run_state)
	var result := game.resolve_with_context("deal_baccarat", 20, run_state, environment, run_state.create_rng("baccarat_contract_deal"), deal_click.get("ui_state", {}))
	_check_action_result_shape(result, "legal", failures)
	_check_action_result_application_contract(before, run_state, result, "baccarat deal result", failures)
	if not ["player", "banker", "tie"].has(str(result.get("baccarat_winner", ""))):
		failures.append("Baccarat resolve produced an invalid winner.")
	if (result.get("baccarat_animation_events", []) as Array).size() < 4:
		failures.append("Baccarat resolve did not publish precomputed deal animation events.")
	var persisted_table: Dictionary = ((environment.get("game_states", {}) as Dictionary).get("baccarat", {}) as Dictionary)
	if int(persisted_table.get("hands_played", 0)) <= 0 or (persisted_table.get("last_result", {}) as Dictionary).is_empty():
		failures.append("Baccarat did not persist the resolved table hand state.")
	var settled_surface := game.surface_state(run_state, environment, {"surface_time_msec": Time.get_ticks_msec() + 7000})
	var settled_explainer: Dictionary = settled_surface.get("baccarat_explainer", {}) if typeof(settled_surface.get("baccarat_explainer", {})) == TYPE_DICTIONARY else {}
	if str(settled_explainer.get("winner", "")) != str(result.get("baccarat_winner", "")):
		failures.append("Baccarat hand explainer winner did not match the resolved hand.")
	if int(settled_explainer.get("player_total", -1)) < 0 or int(settled_explainer.get("banker_total", -1)) < 0:
		failures.append("Baccarat hand explainer did not expose Player and Banker totals.")
	if str(settled_explainer.get("primary", "")).find("Player") < 0 or str(settled_explainer.get("primary", "")).find("Banker") < 0 or str(settled_explainer.get("bet_summary", "")).find("Net") < 0:
		failures.append("Baccarat hand explainer did not summarize totals and player bet outcome.")
	var settled_road: Dictionary = settled_surface.get("baccarat_road", {}) if typeof(settled_surface.get("baccarat_road", {})) == TYPE_DICTIONARY else {}
	if int(settled_road.get("visible_count", 0)) < 1 or (_baccarat_dictionary_array(settled_road.get("beads", []))).is_empty():
		failures.append("Baccarat bead-plate road did not record the resolved hand.")
	var settled_penetration: Dictionary = settled_surface.get("shoe_penetration", {}) if typeof(settled_surface.get("shoe_penetration", {})) == TYPE_DICTIONARY else {}
	if int(settled_penetration.get("used", 0)) <= 0 or int(settled_penetration.get("penetration_percent", 0)) <= 0:
		failures.append("Baccarat shoe penetration did not advance visibly after a hand.")
	var settled_harness := SurfaceHarness.new()
	settled_harness.setup(settled_surface)
	game.draw_surface(settled_harness, settled_surface, {"contract_harness": true})
	var found_winner_label := false
	var found_total_label := false
	for label_value in settled_harness.labels:
		var label_text := str(label_value)
		if label_text.find("WINS") >= 0 or label_text.find("TIE HAND") >= 0:
			found_winner_label = true
		if label_text.find("TOTAL") >= 0:
			found_total_label = true
	if not found_winner_label or not found_total_label:
		failures.append("Baccarat renderer did not expose clear winner and total labels after a hand.")

	var sit_run_state: RunState = RunStateScript.new()
	sit_run_state.start_new("BACCARAT-SITOUT-CONTRACT")
	sit_run_state.bankroll = 1000
	var sit_environment := _surface_contract_environment()
	sit_environment["game_ids"] = ["baccarat"]
	sit_environment["economic_profile"] = {"stake_floor": 20, "stake_ceiling": 200}
	sit_environment["game_states"] = {"baccarat": table.duplicate(true)}
	sit_run_state.current_environment = sit_environment.duplicate(true)
	var sit_deal := game.surface_action_command("baccarat_deal", 0, false, {}, sit_run_state, sit_environment)
	if str(sit_deal.get("action_id", "")) != "deal_baccarat" or not bool(sit_deal.get("resolve", false)) or not bool((sit_deal.get("ui_state", {}) as Dictionary).get("baccarat_sit_out", false)):
		failures.append("Baccarat no-bet deal did not route as a sit-out hand.")
	var sit_before := _run_state_result_snapshot(sit_run_state)
	var sit_result := game.resolve_with_context("deal_baccarat", 20, sit_run_state, sit_environment, sit_run_state.create_rng("baccarat_sitout_deal"), sit_deal.get("ui_state", {}))
	_check_action_result_application_contract(sit_before, sit_run_state, sit_result, "baccarat sit-out result", failures)
	if not bool(sit_result.get("baccarat_sat_out", false)) or int(sit_result.get("baccarat_total_wager", -1)) != 0 or int(sit_result.get("bankroll_delta", 999)) != 0:
		failures.append("Baccarat sit-out hand did not resolve with zero wager and zero bankroll movement.")
	var timer_table: Dictionary = table.duplicate(true)
	timer_table["last_result"] = {}
	timer_table["table_round_timer_started_msec"] = Time.get_ticks_msec() - GameModule.TABLE_ROUND_START_DELAY_MSEC - 100
	var timer_environment := _surface_contract_environment()
	timer_environment["game_ids"] = ["baccarat"]
	timer_environment["economic_profile"] = {"stake_floor": 20, "stake_ceiling": 200}
	timer_environment["game_states"] = {"baccarat": timer_table}
	var timer_run_state: RunState = RunStateScript.new()
	timer_run_state.start_new("BACCARAT-TIMER-CONTRACT")
	timer_run_state.bankroll = 1000
	timer_run_state.current_environment = timer_environment.duplicate(true)
	if not game.surface_needs_auto_tick({"surface_time_msec": Time.get_ticks_msec()}, timer_run_state, timer_environment):
		failures.append("Baccarat table timer did not request an auto hand when due.")
	var auto_deal := game.surface_auto_action_command({"surface_time_msec": Time.get_ticks_msec()}, timer_run_state, timer_environment, {})
	if str(auto_deal.get("action_id", "")) != "deal_baccarat" or not bool(auto_deal.get("direct_resolve", false)) or not bool((auto_deal.get("ui_state", {}) as Dictionary).get("baccarat_sit_out", false)):
		failures.append("Baccarat timer auto command did not resolve a sit-out hand through the normal deal action.")

	var read_fixture := _baccarat_shoe_read_fixture(game, table, "BACCARAT-READ-SHOE-CONTRACT")
	var read_run_state := read_fixture.get("run_state", null) as RunState
	var read_environment: Dictionary = read_fixture.get("environment", {})
	var read_click: Dictionary = read_fixture.get("command", {})
	if str(read_click.get("action_id", "")) != "read_baccarat_shoe" or bool(read_click.get("resolve", false)):
		failures.append("Baccarat read-shoe command did not stage a non-immediate cheat read.")
	var read_ui: Dictionary = read_click.get("ui_state", {})
	var read_challenge: Dictionary = read_ui.get("shoe_read_challenge", {}) if typeof(read_ui.get("shoe_read_challenge", {})) == TYPE_DICTIONARY else {}
	var read_surface := game.surface_state(read_run_state, read_environment, read_ui)
	if read_challenge.is_empty() or not bool(read_surface.get("shoe_read_active", false)) or not bool(read_surface.get("surface_realtime_state_refresh", false)):
		failures.append("Baccarat read-shoe command did not expose a live memory challenge.")
	read_ui["surface_time_msec"] = int(read_challenge.get("started_msec", 0)) + int(read_challenge.get("reveal_msec", 0))
	var read_cues := ["low", "neutral", "zero"]
	var answer_index := read_cues.find(str(read_challenge.get("hidden_answer", "")))
	var answer_command := game.surface_action_command("baccarat_shoe_read_answer", answer_index, false, read_ui, read_run_state, read_environment)
	if not bool(answer_command.get("resolve", false)):
		failures.append("Baccarat read-shoe answer did not resolve after the cue reveal.")
	var read_before := _run_state_result_snapshot(read_run_state)
	var read_result := game.resolve_with_context("read_baccarat_shoe", 0, read_run_state, read_environment, read_run_state.create_rng("baccarat_read_shoe_resolve"), answer_command.get("ui_state", read_ui))
	_check_action_result_shape(read_result, "cheat", failures)
	_check_action_result_application_contract(read_before, read_run_state, read_result, "baccarat read shoe result", failures)
	if int(read_result.get("suspicion_delta", 0)) <= 0 or str(read_result.get("skill_grade", "")) != "perfect" or not bool(read_result.get("baccarat_shoe_read_applied", false)) or (read_result.get("baccarat_shoe_read", {}) as Dictionary).is_empty():
		failures.append("Baccarat read-shoe cheat did not grade correct recall, add heat, and expose shoe-read context.")
	var direct_fixture := _baccarat_shoe_read_fixture(game, table, "BACCARAT-READ-SHOE-DIRECT")
	var direct_run := direct_fixture.get("run_state", null) as RunState
	var direct_environment: Dictionary = direct_fixture.get("environment", {})
	var direct_command: Dictionary = direct_fixture.get("command", {})
	var direct_result := game.resolve_with_context("read_baccarat_shoe", 0, direct_run, direct_environment, direct_run.create_rng("baccarat_read_shoe_direct"), direct_command.get("ui_state", {}))
	if str(direct_result.get("skill_grade", "")) != "miss" or bool(direct_result.get("baccarat_shoe_read_applied", true)) or str(direct_result.get("message", "")).to_lower().find("fade") < 0:
		failures.append("Baccarat unresolved shoe read did not produce a readable miss with no useful composition read.")
	var wrong_fixture := _baccarat_shoe_read_fixture(game, table, "BACCARAT-READ-SHOE-WRONG")
	var wrong_run := wrong_fixture.get("run_state", null) as RunState
	var wrong_environment: Dictionary = wrong_fixture.get("environment", {})
	var wrong_command: Dictionary = wrong_fixture.get("command", {})
	var wrong_ui: Dictionary = wrong_command.get("ui_state", {})
	var wrong_challenge: Dictionary = wrong_ui.get("shoe_read_challenge", {})
	wrong_ui["surface_time_msec"] = int(wrong_challenge.get("started_msec", 0)) + int(wrong_challenge.get("reveal_msec", 0))
	var correct_index := read_cues.find(str(wrong_challenge.get("hidden_answer", "")))
	var wrong_answer := game.surface_action_command("baccarat_shoe_read_answer", (correct_index + 1) % read_cues.size(), false, wrong_ui, wrong_run, wrong_environment)
	var wrong_result := game.resolve_with_context("read_baccarat_shoe", 0, wrong_run, wrong_environment, wrong_run.create_rng("baccarat_read_shoe_wrong"), wrong_answer.get("ui_state", wrong_ui))
	var wrong_message := str(wrong_result.get("message", "")).to_lower()
	if str(wrong_result.get("skill_grade", "")) != "blown" or bool(wrong_result.get("baccarat_shoe_read_applied", true)) or (wrong_message.find("dealer") < 0 and wrong_message.find("stare") < 0):
		failures.append("Baccarat wrong shoe cue did not produce a blown, noticed failure with no useful read.")
	var deterministic_a := _baccarat_shoe_read_fixture(game, table, "BACCARAT-READ-SHOE-DETERMINISTIC")
	var deterministic_b := _baccarat_shoe_read_fixture(game, table, "BACCARAT-READ-SHOE-DETERMINISTIC")
	if JSON.stringify(deterministic_a.get("challenge", {})) != JSON.stringify(deterministic_b.get("challenge", {})):
		failures.append("Baccarat shoe-read challenge was not deterministic for the same seed and input.")
	var sober_read := _baccarat_shoe_read_fixture(game, table, "BACCARAT-READ-SHOE-MODIFIERS")
	var drunk_read := _baccarat_shoe_read_fixture(game, table, "BACCARAT-READ-SHOE-MODIFIERS", 85)
	var item_read := _baccarat_shoe_read_fixture(game, table, "BACCARAT-READ-SHOE-MODIFIERS", 0, "edge_sort_loupe")
	var sober_challenge: Dictionary = sober_read.get("challenge", {})
	var drunk_challenge: Dictionary = drunk_read.get("challenge", {})
	var item_challenge: Dictionary = item_read.get("challenge", {})
	if (drunk_challenge.get("cue_sequence", []) as Array).size() <= (sober_challenge.get("cue_sequence", []) as Array).size() or int(drunk_challenge.get("reveal_msec", 9999)) >= int(sober_challenge.get("reveal_msec", 0)):
		failures.append("Baccarat alcohol did not increase the shoe-read memory load and shorten its reveal.")
	if (item_challenge.get("cue_sequence", []) as Array).size() >= (sober_challenge.get("cue_sequence", []) as Array).size() or int(item_challenge.get("base_heat", 999)) >= int(sober_challenge.get("base_heat", 0)):
		failures.append("Baccarat edge-sort loupe did not reduce shoe-read cue load and base heat.")

	_check_baccarat_edge_sort_contract(game, failures, library)
	if library != null:
		_check_premium_grand_casino_table_contract(library, "baccarat", game, failures)
	_check_baccarat_rules_contract(game, failures)
	_check_baccarat_payout_contract(game, failures)


func _baccarat_shoe_read_fixture(game: GameModule, table: Dictionary, seed_text: String, drunk_level: int = 0, item_id: String = "") -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed_text)
	run_state.bankroll = 1000
	run_state.drunk_level = drunk_level
	if not item_id.is_empty():
		run_state.add_item(item_id)
	var environment := _surface_contract_environment()
	environment["game_ids"] = ["baccarat"]
	environment["economic_profile"] = {"stake_floor": 20, "stake_ceiling": 200}
	environment["game_states"] = {"baccarat": table.duplicate(true)}
	run_state.current_environment = environment.duplicate(true)
	var command := game.surface_action_command("baccarat_read_shoe", 0, false, {"surface_time_msec": 16000}, run_state, environment)
	var ui: Dictionary = command.get("ui_state", {})
	return {"run_state": run_state, "environment": environment, "command": command, "challenge": ui.get("shoe_read_challenge", {})}


func _check_baccarat_edge_sort_contract(game: GameModule, failures: Array, library: ContentLibrary = null) -> void:
	var base_edge_cue_count := 4
	var sig_a := _baccarat_edge_sort_signature(game, "BACCARAT-EDGE-DETERMINISTIC")
	var sig_b := _baccarat_edge_sort_signature(game, "BACCARAT-EDGE-DETERMINISTIC")
	if sig_a.is_empty() or sig_b.is_empty() or JSON.stringify(sig_a) != JSON.stringify(sig_b):
		failures.append("Baccarat edge-sort challenge did not resolve deterministically from the same seed/input.")

	var run_state: RunState = RunStateScript.new()
	run_state.start_new("BACCARAT-EDGE-SORT-CONTRACT")
	run_state.bankroll = 1000
	var environment := _surface_contract_environment()
	environment["game_ids"] = ["baccarat"]
	environment["economic_profile"] = {"stake_floor": 20, "stake_ceiling": 200}
	var table: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("baccarat_edge_table"))
	environment["game_states"] = {"baccarat": table}
	run_state.current_environment = environment.duplicate(true)
	var start_command: Dictionary = game.surface_action_command("baccarat_edge_sort", 0, false, {}, run_state, environment)
	if not bool(start_command.get("handled", false)) or bool(start_command.get("resolve", false)):
		failures.append("Baccarat edge-sort start did not stage a non-immediate challenge.")
	var started_table: Dictionary = ((environment.get("game_states", {}) as Dictionary).get("baccarat", {}) as Dictionary)
	var started_challenge: Dictionary = started_table.get("edge_sort_challenge", {}) if typeof(started_table.get("edge_sort_challenge", {})) == TYPE_DICTIONARY else {}
	if started_challenge.is_empty() or str(started_challenge.get("challenge_id", "")).is_empty():
		failures.append("Baccarat edge-sort start did not persist a challenge on the table.")
	var started_surface := game.surface_state(run_state, environment, start_command.get("ui_state", {}))
	if not bool(started_surface.get("edge_sort_active", false)):
		failures.append("Baccarat edge-sort surface did not expose active challenge state.")

	game.resolve_with_context("deal_baccarat", 20, run_state, environment, run_state.create_rng("baccarat_edge_observe_1"), {"baccarat_sit_out": true})
	var after_one_table: Dictionary = ((environment.get("game_states", {}) as Dictionary).get("baccarat", {}) as Dictionary)
	var after_one_challenge: Dictionary = after_one_table.get("edge_sort_challenge", {}) if typeof(after_one_table.get("edge_sort_challenge", {})) == TYPE_DICTIONARY else {}
	if bool(after_one_challenge.get("ready", false)):
		failures.append("Baccarat edge-sort became ready after one hand; it should require observation across hands.")
	if (_baccarat_dictionary_array(after_one_challenge.get("observed_cues", []))).is_empty():
		failures.append("Baccarat edge-sort did not record card-back cues after an observed hand.")
	run_state.set_environment(environment.duplicate(true))
	var restored: RunState = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	var restored_table: Dictionary = (((restored.current_environment.get("game_states", {}) as Dictionary).get("baccarat", {}) as Dictionary))
	if (_baccarat_dictionary_array((restored_table.get("edge_sort_challenge", {}) as Dictionary).get("observed_cues", []))).is_empty():
		failures.append("Baccarat edge-sort challenge did not survive save/load mid-challenge.")

	game.resolve_with_context("deal_baccarat", 20, run_state, environment, run_state.create_rng("baccarat_edge_observe_2"), {"baccarat_sit_out": true})
	var ready_table: Dictionary = ((environment.get("game_states", {}) as Dictionary).get("baccarat", {}) as Dictionary)
	var ready_challenge: Dictionary = ready_table.get("edge_sort_challenge", {}) if typeof(ready_table.get("edge_sort_challenge", {})) == TYPE_DICTIONARY else {}
	if not bool(ready_challenge.get("ready", false)):
		failures.append("Baccarat edge-sort did not become ready after two observed hands.")
	if not (ready_table.get("edge_sort_edge", {}) as Dictionary).is_empty():
		failures.append("Baccarat edge-sort granted an edge before the memory challenge was resolved.")
	var before := _run_state_result_snapshot(run_state)
	var edge_result := game.resolve_with_context("edge_sort", 0, run_state, environment, run_state.create_rng("baccarat_edge_resolve"), {"edge_sort_challenge": ready_challenge, "edge_sort_answer_mode": "perfect"})
	_check_action_result_shape(edge_result, "cheat", failures)
	_check_action_result_application_contract(before, run_state, edge_result, "baccarat edge-sort result", failures)
	if str(edge_result.get("skill_grade", "")) != "perfect" or not bool(edge_result.get("baccarat_edge_sort_applied", false)):
		failures.append("Baccarat edge-sort perfect memory did not produce an applied perfect grade.")
	if not bool(edge_result.get("skill_security_pressure_checked", false)) or str(edge_result.get("skill_outcome", "")).find("edge_sort") < 0:
		failures.append("Baccarat edge-sort did not expose the shared skill-cheat contract fields.")
	var edge_table: Dictionary = ((environment.get("game_states", {}) as Dictionary).get("baccarat", {}) as Dictionary)
	var edge: Dictionary = edge_table.get("edge_sort_edge", {}) if typeof(edge_table.get("edge_sort_edge", {})) == TYPE_DICTIONARY else {}
	if edge.is_empty() or str(edge.get("predicted_bet", "")).is_empty():
		failures.append("Baccarat edge-sort did not persist a betting edge after a qualifying read.")
	else:
		var predicted := str(edge.get("predicted_bet", ""))
		var edge_deal := game.resolve_with_context("deal_baccarat", 20, run_state, environment, run_state.create_rng("baccarat_edge_use"), {"baccarat_bets": {predicted: 20}})
		if not bool(edge_deal.get("baccarat_edge_sort_edge_used", false)):
			failures.append("Baccarat edge-sort edge was not marked used when betting the predicted side.")
		if str(edge_deal.get("baccarat_winner", "")) != predicted:
			failures.append("Baccarat edge-sort predicted %s but the next hand resolved %s." % [predicted, str(edge_deal.get("baccarat_winner", ""))])

	var marked_run: RunState = RunStateScript.new()
	marked_run.start_new("BACCARAT-EDGE-MARKED")
	marked_run.add_item("marked_cards")
	var marked_environment := _surface_contract_environment()
	marked_environment["game_ids"] = ["baccarat"]
	var marked_table: Dictionary = game.generate_environment_state(marked_run, marked_environment, marked_run.create_rng("baccarat_edge_marked_table"))
	marked_environment["game_states"] = {"baccarat": marked_table}
	var marked_command: Dictionary = game.surface_action_command("baccarat_edge_sort", 0, false, {}, marked_run, marked_environment)
	var marked_challenge: Dictionary = (((marked_environment.get("game_states", {}) as Dictionary).get("baccarat", {}) as Dictionary).get("edge_sort_challenge", {}) as Dictionary)
	if int(marked_challenge.get("required_cue_count", base_edge_cue_count)) >= base_edge_cue_count:
		failures.append("Marked Cards did not reduce Baccarat edge-sort cue load.")
	var notes_run: RunState = RunStateScript.new()
	notes_run.start_new("BACCARAT-EDGE-NOTES")
	notes_run.add_item("scratch_pad")
	var notes_environment := _surface_contract_environment()
	notes_environment["game_ids"] = ["baccarat"]
	var notes_table: Dictionary = game.generate_environment_state(notes_run, notes_environment, notes_run.create_rng("baccarat_edge_notes_table"))
	notes_environment["game_states"] = {"baccarat": notes_table}
	game.surface_action_command("baccarat_edge_sort", 0, false, {}, notes_run, notes_environment)
	var notes_challenge: Dictionary = (((notes_environment.get("game_states", {}) as Dictionary).get("baccarat", {}) as Dictionary).get("edge_sort_challenge", {}) as Dictionary)
	if int(notes_challenge.get("memory_tolerance", 0)) <= 0:
		failures.append("Scratch Pad did not improve Baccarat edge-sort memory tolerance.")
	var drunk_run: RunState = RunStateScript.new()
	drunk_run.start_new("BACCARAT-EDGE-DRUNK")
	drunk_run.drunk_level = 50
	var drunk_environment := _surface_contract_environment()
	drunk_environment["game_ids"] = ["baccarat"]
	var drunk_table: Dictionary = game.generate_environment_state(drunk_run, drunk_environment, drunk_run.create_rng("baccarat_edge_drunk_table"))
	drunk_environment["game_states"] = {"baccarat": drunk_table}
	game.surface_action_command("baccarat_edge_sort", 0, false, {}, drunk_run, drunk_environment)
	var drunk_challenge: Dictionary = (((drunk_environment.get("game_states", {}) as Dictionary).get("baccarat", {}) as Dictionary).get("edge_sort_challenge", {}) as Dictionary)
	if int(drunk_challenge.get("required_cue_count", 0)) <= base_edge_cue_count:
		failures.append("Alcohol did not increase Baccarat edge-sort memory load.")

	if library != null:
		_check_baccarat_edge_sort_grand_casino_pressure(game, library, failures)


func _baccarat_edge_sort_signature(game: GameModule, seed_text: String) -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed_text)
	run_state.bankroll = 1000
	var environment := _surface_contract_environment()
	environment["game_ids"] = ["baccarat"]
	environment["economic_profile"] = {"stake_floor": 20, "stake_ceiling": 200}
	var table: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("baccarat_edge_signature_table"))
	environment["game_states"] = {"baccarat": table}
	run_state.current_environment = environment.duplicate(true)
	game.surface_action_command("baccarat_edge_sort", 0, false, {}, run_state, environment)
	game.resolve_with_context("deal_baccarat", 20, run_state, environment, run_state.create_rng("baccarat_edge_signature_1"), {"baccarat_sit_out": true})
	game.resolve_with_context("deal_baccarat", 20, run_state, environment, run_state.create_rng("baccarat_edge_signature_2"), {"baccarat_sit_out": true})
	var ready_table: Dictionary = ((environment.get("game_states", {}) as Dictionary).get("baccarat", {}) as Dictionary)
	var challenge: Dictionary = ready_table.get("edge_sort_challenge", {}) if typeof(ready_table.get("edge_sort_challenge", {})) == TYPE_DICTIONARY else {}
	var result := game.resolve_with_context("edge_sort", 0, run_state, environment, run_state.create_rng("baccarat_edge_signature_resolve"), {"edge_sort_challenge": challenge, "edge_sort_answer_mode": "perfect"})
	return {
		"hidden_answer": _string_array_from_variant(challenge.get("hidden_answer", [])),
		"observed_hands": _string_array_from_variant(challenge.get("observed_hand_indexes", [])),
		"grade": str(result.get("skill_grade", "")),
		"prediction": result.get("baccarat_edge_sort_edge", {}) if typeof(result.get("baccarat_edge_sort_edge", {})) == TYPE_DICTIONARY else {},
		"suspicion_delta": int(result.get("suspicion_delta", 0)),
	}


func _check_baccarat_edge_sort_grand_casino_pressure(game: GameModule, library: ContentLibrary, failures: Array) -> void:
	var boss_archetype := _archetype_by_id(library, "grand_casino")
	if boss_archetype.is_empty():
		failures.append("Baccarat edge-sort Grand Casino pressure test requires the grand_casino archetype.")
		return
	var run_state := _grand_casino_game_fixture_run(library, boss_archetype, "baccarat", game, "BACCARAT-EDGE-WATCHED")
	var environment: Dictionary = run_state.current_environment
	environment["turns"] = 0
	var table: Dictionary = ((environment.get("game_states", {}) as Dictionary).get("baccarat", {}) as Dictionary)
	var patrons := _baccarat_dictionary_array(table.get("patrons", []))
	for i in range(patrons.size()):
		var patron: Dictionary = patrons[i]
		patron["watching"] = true
		patrons[i] = patron
	table["patrons"] = patrons
	var watched_states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	watched_states["baccarat"] = table
	environment["game_states"] = watched_states
	run_state.set_environment(environment)
	var objective: Dictionary = boss_archetype.get("demo_objective", {}) if typeof(boss_archetype.get("demo_objective", {})) == TYPE_DICTIONARY else {}
	var showdown_threshold := clampi(int(objective.get("showdown_heat_threshold", 70)), 1, 100)
	run_state.add_suspicion("baccarat_edge_preheat", maxi(0, showdown_threshold - 1), "behavior")
	environment = run_state.current_environment
	game.surface_action_command("baccarat_edge_sort", 0, false, {}, run_state, environment)
	game.resolve_with_context("deal_baccarat", 20, run_state, environment, run_state.create_rng("baccarat_edge_watch_1"), {"baccarat_sit_out": true})
	game.resolve_with_context("deal_baccarat", 20, run_state, environment, run_state.create_rng("baccarat_edge_watch_2"), {"baccarat_sit_out": true})
	var ready_table: Dictionary = ((environment.get("game_states", {}) as Dictionary).get("baccarat", {}) as Dictionary)
	var ready_challenge: Dictionary = ready_table.get("edge_sort_challenge", {}) if typeof(ready_table.get("edge_sort_challenge", {})) == TYPE_DICTIONARY else {}
	var result := game.resolve_with_context("edge_sort", 0, run_state, environment, run_state.create_rng("baccarat_edge_watch_resolve"), {"edge_sort_challenge": ready_challenge, "edge_sort_answer_mode": "blown"})
	if str(result.get("skill_grade", "")) != "blown" or not bool(result.get("pit_boss_watched", false)):
		failures.append("Baccarat edge-sort watched failure did not produce a blown watched result.")
	if not bool(run_state.narrative_flags.get("grand_casino_attention_watched_cheat", false)):
		failures.append("Baccarat edge-sort watched failure did not mark Grand Casino watched-cheat attention.")
	var status: Dictionary = run_state.demo_objective_status()
	if not bool(status.get("staff_attention_active", false)):
		failures.append("Baccarat edge-sort watched failure did not activate Grand Casino staff attention.")
	if not bool(status.get("showdown_pending", false)) and not bool(status.get("showdown_active", false)):
		failures.append("Baccarat edge-sort watched failure did not queue Grand Casino showdown pressure.")


func _baccarat_target_index(targets: Array, target_id: String) -> int:
	for i in range(targets.size()):
		if typeof(targets[i]) == TYPE_DICTIONARY and str((targets[i] as Dictionary).get("id", "")) == target_id:
			return i
	return -1


func _baccarat_dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append((entry as Dictionary).duplicate(true))
	return result


func _check_baccarat_rules_contract(game: GameModule, failures: Array) -> void:
	if int(game.call("_baccarat_card_value", {"rank": 14, "suit": 0})) != 1:
		failures.append("Baccarat Ace card value was not 1.")
	if int(game.call("_baccarat_card_value", {"rank": 9, "suit": 0})) != 9:
		failures.append("Baccarat 9 card value was not 9.")
	if int(game.call("_baccarat_card_value", {"rank": 13, "suit": 0})) != 0:
		failures.append("Baccarat face-card value was not 0.")
	if int(game.call("_hand_total", [{"rank": 14}, {"rank": 9}, {"rank": 8}])) != 8:
		failures.append("Baccarat hand total did not use modulo 10.")
	if not bool(game.call("_is_natural", 8, 4)) or not bool(game.call("_is_natural", 2, 9)) or bool(game.call("_is_natural", 7, 7)):
		failures.append("Baccarat natural 8/9 detection failed.")
	if not bool(game.call("_player_should_draw", 5)) or bool(game.call("_player_should_draw", 6)):
		failures.append("Baccarat Player draw rule failed.")
	for banker_total in range(0, 8):
		var stood_actual := bool(game.call("_banker_should_draw", banker_total, -1, true))
		var stood_expected := banker_total <= 5
		if stood_actual != stood_expected:
			failures.append("Baccarat Banker stood-player tableau failed for Banker %d." % banker_total)
		for player_third in range(0, 10):
			var actual := bool(game.call("_banker_should_draw", banker_total, player_third, false))
			var expected := _expected_baccarat_banker_draw(banker_total, player_third)
			if actual != expected:
				failures.append("Baccarat Banker third-card tableau failed for Banker %d, Player third %d." % [banker_total, player_third])
	_check_baccarat_tableau_hand_fixture(game, failures, "natural stops draw", [
		_baccarat_fixture_card(4, 0, 0),
		_baccarat_fixture_card(2, 1, 0),
		_baccarat_fixture_card(4, 2, 0),
		_baccarat_fixture_card(3, 3, 0),
	], {"natural": true, "player_drew": false, "banker_drew": false, "winner": "player", "player_initial_total": 8, "banker_initial_total": 5})
	_check_baccarat_tableau_hand_fixture(game, failures, "Player stands, Banker 5 draws", [
		_baccarat_fixture_card(3, 0, 1),
		_baccarat_fixture_card(2, 1, 1),
		_baccarat_fixture_card(3, 2, 1),
		_baccarat_fixture_card(3, 3, 1),
		_baccarat_fixture_card(9, 0, 2),
	], {"natural": false, "player_drew": false, "banker_drew": true, "winner": "player", "player_total": 6, "banker_total": 4})
	_check_baccarat_tableau_hand_fixture(game, failures, "Banker 3 stands on Player third 8", [
		_baccarat_fixture_card(10, 0, 3),
		_baccarat_fixture_card(14, 1, 3),
		_baccarat_fixture_card(10, 2, 3),
		_baccarat_fixture_card(2, 3, 3),
		_baccarat_fixture_card(8, 0, 4),
	], {"natural": false, "player_drew": true, "banker_drew": false, "player_third_value": 8, "winner": "player"})
	_check_baccarat_tableau_hand_fixture(game, failures, "Banker 3 draws on Player third 7", [
		_baccarat_fixture_card(10, 1, 4),
		_baccarat_fixture_card(14, 2, 4),
		_baccarat_fixture_card(10, 3, 4),
		_baccarat_fixture_card(2, 0, 5),
		_baccarat_fixture_card(7, 1, 5),
		_baccarat_fixture_card(10, 2, 5),
	], {"natural": false, "player_drew": true, "banker_drew": true, "player_third_value": 7})
	_check_baccarat_tableau_hand_fixture(game, failures, "Banker 4 draws on Player third 2", [
		_baccarat_fixture_card(10, 3, 5),
		_baccarat_fixture_card(2, 0, 6),
		_baccarat_fixture_card(10, 1, 6),
		_baccarat_fixture_card(2, 2, 6),
		_baccarat_fixture_card(2, 3, 6),
		_baccarat_fixture_card(10, 0, 7),
	], {"natural": false, "player_drew": true, "banker_drew": true, "player_third_value": 2})
	_check_baccarat_tableau_hand_fixture(game, failures, "Banker 5 stands on Player third 3", [
		_baccarat_fixture_card(10, 1, 7),
		_baccarat_fixture_card(2, 2, 7),
		_baccarat_fixture_card(10, 3, 7),
		_baccarat_fixture_card(3, 0, 8),
		_baccarat_fixture_card(3, 1, 8),
	], {"natural": false, "player_drew": true, "banker_drew": false, "player_third_value": 3, "winner": "banker"})
	_check_baccarat_tableau_hand_fixture(game, failures, "Banker 6 draws on Player third 6", [
		_baccarat_fixture_card(10, 2, 8),
		_baccarat_fixture_card(3, 3, 8),
		_baccarat_fixture_card(10, 0, 9),
		_baccarat_fixture_card(3, 1, 9),
		_baccarat_fixture_card(6, 2, 9),
		_baccarat_fixture_card(10, 3, 9),
	], {"natural": false, "player_drew": true, "banker_drew": true, "player_third_value": 6, "winner": "tie"})
	_check_baccarat_tableau_hand_fixture(game, failures, "Banker 6 stands on Player third 5", [
		_baccarat_fixture_card(10, 0, 10),
		_baccarat_fixture_card(3, 1, 10),
		_baccarat_fixture_card(10, 2, 10),
		_baccarat_fixture_card(3, 3, 10),
		_baccarat_fixture_card(5, 0, 11),
	], {"natural": false, "player_drew": true, "banker_drew": false, "player_third_value": 5, "winner": "banker"})


func _expected_baccarat_banker_draw(banker_total: int, player_third_value: int) -> bool:
	match banker_total:
		0, 1, 2:
			return true
		3:
			return player_third_value != 8
		4:
			return player_third_value >= 2 and player_third_value <= 7
		5:
			return player_third_value >= 4 and player_third_value <= 7
		6:
			return player_third_value == 6 or player_third_value == 7
		_:
			return false


func _check_baccarat_tableau_hand_fixture(game: GameModule, failures: Array, label: String, fixture_cards: Array, expected: Dictionary) -> void:
	var shoe := fixture_cards.duplicate(true)
	while shoe.size() < 16:
		shoe.append(_baccarat_fixture_card(2 + (shoe.size() % 8), shoe.size() % 4, 50 + shoe.size()))
	var table := {
		"schema": "baccarat_table_state",
		"version": 1,
		"variant": "mini_baccarat",
		"deck_count": 8,
		"rules": game.call("_default_rules", 8),
		"shoe": shoe,
		"discard": [],
		"burn_cards": [],
		"shoe_remaining": shoe.size(),
		"cut_card_remaining": 4,
		"reshuffle_pending": false,
		"hands_played": 0,
		"hand_history": [],
		"shoe_history": [],
	}
	var rng: RngStream = RngStream.new()
	rng.configure(1000 + fixture_cards.size())
	var hand: Dictionary = game.call("_resolve_baccarat_hand", table, rng)
	for key in expected.keys():
		var expected_value: Variant = expected.get(key)
		var actual_value: Variant = hand.get(key)
		if actual_value != expected_value:
			failures.append("Baccarat tableau fixture '%s' expected %s=%s, got %s." % [label, str(key), str(expected_value), str(actual_value)])
	if not (_baccarat_dictionary_array(hand.get("animation_events", []))).is_empty() and not bool(hand.get("natural", false)):
		if abs(int(hand.get("player_total", 0)) - int(hand.get("banker_total", 0))) <= 1:
			var found_squeeze := false
			for event_value in _baccarat_dictionary_array(hand.get("animation_events", [])):
				var event: Dictionary = event_value
				if str(event.get("type", "")) == "squeeze":
					found_squeeze = true
			if not found_squeeze:
				failures.append("Baccarat close-hand fixture '%s' did not emit a squeeze reveal event." % label)


func _baccarat_fixture_card(rank: int, suit: int, deck: int) -> Dictionary:
	return {"rank": rank, "suit": suit, "deck": deck}


func _check_baccarat_payout_contract(game: GameModule, failures: Array) -> void:
	var rules := {
		"player_payout": 1,
		"banker_payout": 1,
		"banker_commission_rate": 0.05,
		"banker_commission_rounding": "ceil_whole_unit",
		"tie_payout": 8,
		"player_pair_payout": 11,
		"banker_pair_payout": 11,
	}
	if int(game.call("_banker_commission", 100, rules)) != 5 or int(game.call("_banker_commission", 20, rules)) != 1:
		failures.append("Baccarat 5% Banker commission did not round as documented.")
	var player_hand := {
		"winner": "player",
		"player_pair": true,
		"banker_pair": false,
	}
	var player_settlement: Dictionary = game.call("_settle_baccarat_bets", {"player": 10, "banker": 10, "tie": 10, "player_pair": 10, "banker_pair": 10}, player_hand, rules)
	if int(player_settlement.get("bankroll_delta", 999)) != 90:
		failures.append("Baccarat Player/pair settlement expected +90, got %+d." % int(player_settlement.get("bankroll_delta", 0)))
	var banker_hand := {
		"winner": "banker",
		"player_pair": false,
		"banker_pair": true,
	}
	var banker_settlement: Dictionary = game.call("_settle_baccarat_bets", {"banker": 20, "banker_pair": 10}, banker_hand, rules)
	if int(banker_settlement.get("bankroll_delta", 999)) != 129 or int(banker_settlement.get("commission", 0)) != 1:
		failures.append("Baccarat Banker commission settlement expected +129 with $1 commission, got %+d and commission $%d." % [int(banker_settlement.get("bankroll_delta", 0)), int(banker_settlement.get("commission", 0))])
	var hundred_banker: Dictionary = game.call("_settle_baccarat_bets", {"banker": 100}, banker_hand, rules)
	if int(hundred_banker.get("bankroll_delta", 999)) != 95 or int(hundred_banker.get("commission", 0)) != 5:
		failures.append("Baccarat $100 Banker settlement expected +95 after 5% commission.")
	var tie_hand := {
		"winner": "tie",
		"player_pair": false,
		"banker_pair": false,
	}
	var tie_settlement: Dictionary = game.call("_settle_baccarat_bets", {"player": 10, "banker": 10, "tie": 10}, tie_hand, rules)
	if int(tie_settlement.get("bankroll_delta", 999)) != 80:
		failures.append("Baccarat Tie settlement expected main pushes and +80 tie win, got %+d." % int(tie_settlement.get("bankroll_delta", 0)))


func _check_blackjack_surface_contract(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("BLACKJACK-SURFACE-CONTRACT")
	var environment := _surface_contract_environment()
	var generated_state := game.generate_environment_state(run_state, environment, run_state.create_rng("blackjack_contract_table"))
	if generated_state.is_empty():
		failures.append("Blackjack did not generate table state for an environment.")
	var generated_deck_count := int(generated_state.get("deck_count", 0))
	var generated_shoe: Array = generated_state.get("shoe", []) as Array
	if generated_deck_count <= 0 or generated_shoe.size() != generated_deck_count * 52:
		failures.append("Blackjack generated table did not create a shoe from its declared deck count.")
	var generated_composition: Dictionary = generated_state.get("shoe_composition", {}) if typeof(generated_state.get("shoe_composition", {})) == TYPE_DICTIONARY else {}
	if int(generated_composition.get("total", -1)) != generated_shoe.size():
		failures.append("Blackjack generated shoe composition did not match the actual remaining shoe.")
	if str(generated_state.get("shoe_label", "")).find(str(generated_deck_count)) < 0 or str(generated_state.get("count_efficiency", "")).is_empty():
		failures.append("Blackjack generated table did not describe the shoe deck count and count efficiency.")
	var generated_side_bets: Array = generated_state.get("side_bets", []) as Array
	if generated_side_bets.size() > 2:
		failures.append("Blackjack generated more than two possible side bets.")
	environment["game_states"] = {"blackjack": generated_state}
	var surface := game.surface_state(run_state, environment, {})
	if str(surface.get("surface_renderer", "")) != "blackjack":
		failures.append("Blackjack surface did not route to the blackjack renderer.")
	_check_idle_animation_liveness_contract(surface, "Blackjack betting surface", failures)
	if not bool(surface.get("surface_controls_native", false)):
		failures.append("Blackjack surface did not expose native surface controls.")
	if not bool(surface.get("can_deal", false)):
		failures.append("Blackjack surface did not start in a deal-ready betting phase.")
	if not bool(surface.get("surface_animates_idle", false)):
		failures.append("Blackjack betting surface must declare idle animation liveness for dealer, patron, and timer motion.")
	if (surface.get("patrons", []) as Array).is_empty() or (surface.get("dealer_profile", {}) as Dictionary).is_empty():
		failures.append("Blackjack pre-deal surface did not expose its animated patrons and dealer.")
	if bool(surface.get("surface_realtime_state_refresh", false)):
		failures.append("Blackjack betting surface must not rebuild full realtime snapshots while idle.")
	if (surface.get("table_round_timer", {}) as Dictionary).is_empty():
		failures.append("Blackjack betting surface did not expose table-round timer state.")
	if (surface.get("side_bets_available", []) as Array).is_empty():
		failures.append("Blackjack generated table did not expose side bets.")
	if (surface.get("side_bets_available", []) as Array).size() > 2:
		failures.append("Blackjack surface exposed more than two possible side bets.")
	for side_bet_value in (surface.get("side_bets_available", []) as Array):
		if typeof(side_bet_value) != TYPE_DICTIONARY:
			continue
		var side_bet: Dictionary = side_bet_value
		if (side_bet.get("rules", []) as Array).is_empty() or (side_bet.get("payouts", []) as Array).is_empty():
			failures.append("Blackjack side bet did not expose rule and payout text for the highlight overlay.")
	if int(surface.get("total_wager_cost", 0)) <= 0:
		failures.append("Blackjack surface did not expose total wager cost.")
	var blackjack_harness := SurfaceHarness.new()
	blackjack_harness.setup(surface)
	game.draw_surface(blackjack_harness, surface, {"contract_harness": true})
	var blackjack_deal_hit := _surface_harness_first_hit(blackjack_harness, "blackjack_deal", 0)
	_check_canvas_hit_dispatch(surface, blackjack_deal_hit.get("rect", Rect2()), "blackjack_deal", 0, "Blackjack deal canvas dispatch", failures)
	_check_canvas_hit_dispatch(surface, Rect2(128, 258, 26, 42), "surface_stake_up", -1, "Blackjack bound stake-up chip dispatch", failures, "blackjack_chip", 0)
	var spam_ui: Dictionary = {}
	var spam_chips: Array = surface.get("chip_denominations", []) as Array
	if spam_chips.is_empty():
		failures.append("Blackjack chip-spam regression had no chip denominations to press.")
	else:
		for click_index in range(180):
			var chip_index := click_index % spam_chips.size()
			var chip_click := game.surface_action_command("blackjack_chip", chip_index, false, spam_ui, run_state, environment)
			if not bool(chip_click.get("handled", false)):
				failures.append("Blackjack chip-spam click %d on chip index %d was not handled." % [click_index, chip_index])
				break
			spam_ui = chip_click.get("ui_state", {}) if typeof(chip_click.get("ui_state", {})) == TYPE_DICTIONARY else {}
			var spam_surface := game.surface_state(run_state, environment, spam_ui)
			var spam_stake := int(spam_surface.get("selected_stake", 0))
			if spam_stake < int(spam_surface.get("stake_floor", 1)) or spam_stake > int(spam_surface.get("stake_ceiling", 1)):
				failures.append("Blackjack chip-spam click %d pushed stake out of bounds: %d not in %d-%d." % [click_index, spam_stake, int(spam_surface.get("stake_floor", 1)), int(spam_surface.get("stake_ceiling", 1))])
				break
		var spam_deal := game.surface_action_command("blackjack_deal", 0, false, spam_ui, run_state, environment)
		if str(spam_deal.get("action_id", "")) != "blackjack_place_bet" or not bool(spam_deal.get("direct_resolve", false)):
			failures.append("Blackjack chip-spam state did not remain dealable after rapid chip presses.")
	var side_bet_hover_harness := SurfaceHarness.new()
	side_bet_hover_harness.setup(surface)
	side_bet_hover_harness.hovered_action = "blackjack_side_bet"
	side_bet_hover_harness.hovered_index = 0
	game.draw_surface(side_bet_hover_harness, surface, {"contract_harness": true})
	var side_bet_overlay_found := false
	for label_value in side_bet_hover_harness.labels:
		if str(label_value).find("SIDE BET RULES") >= 0:
			side_bet_overlay_found = true
			break
	if not side_bet_overlay_found:
		failures.append("Blackjack side-bet hover did not draw the rules overlay.")
	var side_bet_active_surface: Dictionary = surface.duplicate(true)
	var active_surface_bets: Array = side_bet_active_surface.get("side_bets_available", []) as Array
	if not active_surface_bets.is_empty() and typeof(active_surface_bets[0]) == TYPE_DICTIONARY:
		side_bet_active_surface["side_bets_active"] = [str((active_surface_bets[0] as Dictionary).get("id", ""))]
		var side_bet_active_harness := SurfaceHarness.new()
		side_bet_active_harness.setup(side_bet_active_surface)
		game.draw_surface(side_bet_active_harness, side_bet_active_surface, {"contract_harness": true})
		for label_value in side_bet_active_harness.labels:
			if str(label_value).find("SIDE BET RULES") >= 0:
				failures.append("Blackjack side-bet rules overlay stayed visible from active selection without hover.")
				break
	var confirm_deal_click := game.surface_action_command("blackjack_deal", 0, true, {}, run_state, environment)
	if bool(confirm_deal_click.get("resolve", false)):
		failures.append("Blackjack confirmed Deal quick-settled instead of starting the visible card-deal animation.")
	if (confirm_deal_click.get("ui_state", {}) as Dictionary).get("round_terminal", false):
		failures.append("Blackjack confirmed Deal marked the hand terminal before any player action.")
	var selected_deal_click := game.surface_action_command("blackjack_deal", 0, false, {"selected_action_id": "play_basic", "selected_action_kind": "legal"}, run_state, environment)
	if str(selected_deal_click.get("action_id", "")) != "blackjack_place_bet" or not bool(selected_deal_click.get("direct_resolve", false)):
		failures.append("Blackjack opening Deal did not route through upfront wager placement when play_basic was already selected.")
	if bool((selected_deal_click.get("ui_state", {}) as Dictionary).get("round_terminal", false)):
		failures.append("Blackjack selected opening Deal marked the hand terminal before player action.")
	var deal_click := game.surface_action_command("blackjack_deal", 0, false, {}, run_state, environment)
	var deal_ui: Dictionary = deal_click.get("ui_state", {})
	if (deal_ui.get("player_hands", []) as Array).is_empty():
		failures.append("Blackjack deal did not create an animated table hand.")
	var deal_remaining_shoe: Array = deal_ui.get("shoe", []) as Array
	if not deal_remaining_shoe.is_empty():
		failures.append("Blackjack deal kept a materialized shoe in transient UI state instead of the compact consumed-card cursor.")
	if int(deal_ui.get("cards_consumed", 0)) <= 0 or int(deal_ui.get("shoe_remaining", generated_shoe.size())) >= generated_shoe.size():
		failures.append("Blackjack deal did not advance the compact shoe cursor.")
	var dealt_surface := game.surface_state(run_state, environment, deal_ui)
	if int(dealt_surface.get("blackjack_total", 0)) <= 0:
		failures.append("Blackjack dealt surface did not expose a visible hand total.")
	var dealt_patrons: Array = dealt_surface.get("patrons", [])
	if dealt_patrons.is_empty():
		failures.append("Blackjack dealt surface dropped the other table patrons.")
	else:
		for patron_value in dealt_patrons:
			var patron: Dictionary = patron_value if typeof(patron_value) == TYPE_DICTIONARY else {}
			if (patron.get("cards", []) as Array).size() < 2:
				failures.append("Blackjack dealt surface did not expose cards for every other patron.")
				break
	var deal_events: Array = dealt_surface.get("deal_animation_events", []) as Array
	if deal_events.size() < 4:
		failures.append("Blackjack initial deal did not expose card-by-card animation events.")
	else:
		var first_deal_event: Dictionary = deal_events[0] if typeof(deal_events[0]) == TYPE_DICTIONARY else {}
		if str(first_deal_event.get("zone", "")) == "player" and float(first_deal_event.get("scale", 0.0)) < 0.80:
			failures.append("Blackjack player cards did not use the enlarged readable scale.")
		if str(first_deal_event.get("zone", "")) != "player" or not first_deal_event.has("from") or not first_deal_event.has("to"):
			failures.append("Blackjack deal animation events did not include normalized card targets.")
		var prior_delay := -1
		for event_value in deal_events.slice(0, mini(4, deal_events.size())):
			if typeof(event_value) != TYPE_DICTIONARY:
				continue
			var event: Dictionary = event_value
			var event_delay := int(event.get("delay_msec", -1))
			if event_delay <= prior_delay:
				failures.append("Blackjack initial deal events were not staggered card by card.")
				break
			prior_delay = event_delay
	var opening_deal_harness := SurfaceHarness.new()
	opening_deal_harness.setup(dealt_surface)
	opening_deal_harness.animation_active = true
	opening_deal_harness.animation_elapsed = 0.05
	if not bool(game.call("_card_waiting_for_deal_animation", opening_deal_harness, dealt_surface, "player", 0, 0)):
		failures.append("Blackjack initial deal exposed the first player card before its animation delay.")
	if not bool(game.call("_card_waiting_for_deal_animation", opening_deal_harness, dealt_surface, "dealer", 0, 0)):
		failures.append("Blackjack initial deal exposed the dealer upcard before its animation delay.")
	opening_deal_harness.animation_elapsed = 3.5
	if bool(game.call("_card_waiting_for_deal_animation", opening_deal_harness, dealt_surface, "player", 0, 0)):
		failures.append("Blackjack initial deal kept the first player card hidden after the animation window.")
	var dealer_focus: Dictionary = dealt_surface.get("dealer_focus", {}) if typeof(dealt_surface.get("dealer_focus", {})) == TYPE_DICTIONARY else {}
	if not dealer_focus.has("gaze_phase") or not dealer_focus.has("peek_danger") or not dealer_focus.has("scan_phase") or not dealer_focus.has("watching_player") or not dealer_focus.has("peek_window_open"):
		failures.append("Blackjack dealer focus did not expose visual read timing fields.")
	var dealt_channel_found := false
	for channel_value in dealt_surface.get("surface_animation_channels", []):
		if typeof(channel_value) == TYPE_DICTIONARY and str((channel_value as Dictionary).get("id", "")) == "blackjack_deal":
			dealt_channel_found = not str((channel_value as Dictionary).get("active_id", "")).is_empty()
	if not dealt_channel_found:
		failures.append("Blackjack dealt surface did not activate the card-deal animation channel.")
	if bool(dealt_surface.get("surface_realtime_state_refresh", false)):
		failures.append("Blackjack dealt surface should compute live table focus during draw without full snapshot rebuilds.")
	var deal_overlay_harness := SurfaceHarness.new()
	deal_overlay_harness.setup(dealt_surface)
	deal_overlay_harness.animation_active = true
	deal_overlay_harness.animation_elapsed = 0.55
	game.draw_surface(deal_overlay_harness, dealt_surface, {"contract_harness": true})
	var overlay_drew_player_hand := false
	for label_value in deal_overlay_harness.labels:
		if str(label_value).begins_with("H1"):
			overlay_drew_player_hand = true
			break
	if not overlay_drew_player_hand:
		failures.append("Blackjack main surface did not keep player cards/hands live during deal animation.")
	var web_idle_harness := SurfaceHarness.new()
	web_idle_harness.setup(dealt_surface)
	web_idle_harness.low_detail_idle = true
	web_idle_harness.record_draw_rects = true
	web_idle_harness.flicker_value = 1.2
	game.draw_surface(web_idle_harness, dealt_surface, {"contract_harness": true})
	for patron_index in range(dealt_patrons.size()):
		var patron_card_origin: Vector2 = game.call("_patron_hand_base_position", patron_index)
		var patron_card_faces := 0
		for record_value in web_idle_harness.draw_rect_records:
			var record: Dictionary = record_value if typeof(record_value) == TYPE_DICTIONARY else {}
			var card_rect: Rect2 = record.get("rect", Rect2())
			if bool(record.get("filled", false)) \
					and Rect2(patron_card_origin + Vector2(-2, -2), Vector2(76, 36)).has_point(card_rect.position) \
					and card_rect.size.x >= 17.0 and card_rect.size.x <= 19.0 \
					and card_rect.size.y >= 25.0 and card_rect.size.y <= 27.0:
				patron_card_faces += 1
		if patron_card_faces < 2:
			failures.append("Blackjack Web idle renderer omitted the visible cards for patron %d." % patron_index)
			break
	web_idle_harness.animation_active = true
	if bool(game.call("_surface_low_detail_idle", web_idle_harness)):
		failures.append("Blackjack Web fallback stayed in low-detail mode during an active deal animation.")
	var book_run_state: RunState = RunStateScript.new()
	book_run_state.start_new("BLACKJACK-BASIC-STRATEGY-CARD")
	book_run_state.add_item("basic_strategy_card")
	var book_environment := _surface_contract_environment()
	var book_table := generated_state.duplicate(true)
	book_table["shoe_cursor"] = 0
	book_table["patrons"] = []
	book_table["side_bets"] = []
	book_table["rules"] = {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}
	book_table["shoe"] = [
		{"rank": 10, "suit": 0}, {"rank": 10, "suit": 1}, {"rank": 6, "suit": 2}, {"rank": 7, "suit": 3},
		{"rank": 5, "suit": 0}, {"rank": 9, "suit": 1}, {"rank": 4, "suit": 2}, {"rank": 3, "suit": 3}
	]
	book_environment["game_states"] = {"blackjack": book_table}
	var book_deal: Dictionary = game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, book_run_state, book_environment)
	var book_surface := game.surface_state(book_run_state, book_environment, book_deal.get("ui_state", {}))
	var book_advice: Dictionary = book_surface.get("basic_strategy_advice", {}) if typeof(book_surface.get("basic_strategy_advice", {})) == TYPE_DICTIONARY else {}
	if not bool(book_advice.get("visible", false)) or str(book_advice.get("action", "")) != "surrender":
		failures.append("Basic Strategy Card did not expose the expected book play for hard 16 versus dealer 10.")
	var book_harness := SurfaceHarness.new()
	book_harness.setup(book_surface)
	game.draw_surface(book_harness, book_surface, {"contract_harness": true})
	var found_book_label := false
	var found_book_action := false
	for label_value in book_harness.labels:
		var label_text := str(label_value).to_upper()
		if label_text.find("BOOK") >= 0:
			found_book_label = true
		if label_text.find("SURRENDER") >= 0:
			found_book_action = true
	if not found_book_label or not found_book_action:
		failures.append("Basic Strategy Card did not draw the compact book-play indicator.")
	var watch_run_state: RunState = RunStateScript.new()
	watch_run_state.start_new("BLACKJACK-HIGH-ROLLER-WATCH")
	watch_run_state.bankroll = 1000
	watch_run_state.add_item("high_roller_watch")
	var watch_environment := _surface_contract_environment()
	watch_environment["economic_profile"] = {"stake_floor": 5, "stake_ceiling": 20}
	watch_environment["game_states"] = {"blackjack": generated_state.duplicate(true)}
	var watch_actions: Dictionary = game.actions(watch_run_state, watch_environment)
	if int(watch_actions.get("stake_floor", 0)) != 20 or int(watch_actions.get("stake_ceiling", 0)) != 40:
		failures.append("High Roller Watch did not raise blackjack minimum to the old max and double the table max.")
	var watch_surface := game.surface_state(watch_run_state, watch_environment, {})
	if int(watch_surface.get("selected_stake", 0)) != 20:
		failures.append("High Roller Watch did not clamp blackjack's starting stake to the raised table minimum.")
	var broken_focus_run_state: RunState = RunStateScript.new()
	broken_focus_run_state.start_new("BLACKJACK-BROKEN-CUFFLINKS-FOCUS")
	broken_focus_run_state.add_item("broken_cufflinks")
	var broken_focus_environment := _surface_contract_environment()
	broken_focus_environment["game_states"] = {"blackjack": generated_state.duplicate(true)}
	var broken_focus_deal: Dictionary = game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, broken_focus_run_state, broken_focus_environment)
	var broken_focus_surface := game.surface_state(broken_focus_run_state, broken_focus_environment, broken_focus_deal.get("ui_state", {}))
	var broken_focus: Dictionary = broken_focus_surface.get("dealer_focus", {}) if typeof(broken_focus_surface.get("dealer_focus", {})) == TYPE_DICTIONARY else {}
	if int(broken_focus.get("peek_window_percent", 100)) != 50:
		failures.append("Broken Cufflinks did not halve the blackjack peek timing window.")
	_check_blackjack_surface_time_resolve_determinism(game, generated_state, failures)
	var control_surface: Dictionary = dealt_surface.duplicate(true)
	control_surface["can_deal"] = false
	control_surface["can_hit"] = true
	control_surface["can_stand"] = true
	control_surface["can_double"] = true
	control_surface["can_split"] = true
	control_surface["can_surrender"] = true
	control_surface["peek_available"] = true
	control_surface["dealer_hole_visible"] = false
	control_surface["settle_available"] = false
	var control_harness := SurfaceHarness.new()
	control_harness.setup(control_surface)
	game.draw_surface(control_harness, control_surface, {"contract_harness": true})
	_check_blackjack_control_hit_regions(control_harness, failures)
	var focus_runtime: Dictionary = dealt_surface.get("dealer_focus_runtime", {}) if typeof(dealt_surface.get("dealer_focus_runtime", {})) == TYPE_DICTIONARY else {}
	if focus_runtime.is_empty():
		failures.append("Blackjack dealt surface did not expose lightweight dealer focus runtime data.")
	var surface_patrons: Array = dealt_surface.get("patrons", []) as Array
	if surface_patrons.is_empty():
		failures.append("Blackjack dealt surface did not expose table patrons.")
	else:
		var first_patron: Dictionary = surface_patrons[0] if typeof(surface_patrons[0]) == TYPE_DICTIONARY else {}
		if not first_patron.has("behavior_phase") or not first_patron.has("tell"):
			failures.append("Blackjack patron surface data did not expose animated behavior tells.")
	_check_surface_command_non_mutating(game, "blackjack_hit", 0, false, deal_ui, run_state, environment, "blackjack hit", failures)
	var first_click := game.surface_action_command("blackjack_stand", 0, false, deal_ui, run_state, environment)
	if str(first_click.get("action_kind", "")) != "legal":
		failures.append("Blackjack stand did not map to a legal action.")
	if not bool(first_click.get("resolve", false)):
		failures.append("Blackjack stand did not immediately resolve a completed one-hand round.")
	if bool(first_click.get("preserve_surface_ui_state", false)):
		failures.append("Blackjack stand preserved stale completed-hand UI state after resolution.")
	var settle_anim_run_state: RunState = RunStateScript.new()
	settle_anim_run_state.start_new("BLACKJACK-STAND-ANIMATION")
	settle_anim_run_state.bankroll = 1000
	var settle_anim_environment := _surface_contract_environment()
	settle_anim_environment["game_states"] = {"blackjack": generated_state.duplicate(true)}
	var settle_anim_deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, settle_anim_run_state, settle_anim_environment)
	var settle_anim_stand := game.surface_action_command("blackjack_stand", 0, true, settle_anim_deal.get("ui_state", {}), settle_anim_run_state, settle_anim_environment)
	var settle_anim_result := game.resolve_with_context("play_basic", 5, settle_anim_run_state, settle_anim_environment, settle_anim_run_state.create_rng("blackjack_stand_animation_resolve"), settle_anim_stand.get("ui_state", {}))
	if not bool(settle_anim_result.get("ok", false)):
		failures.append("Blackjack stand animation fixture did not resolve through the normal play_basic path.")
	var settle_anim_surface := game.surface_state(settle_anim_run_state, settle_anim_environment, {})
	var settlement_deal_events: Array = settle_anim_surface.get("deal_animation_events", []) as Array
	if settlement_deal_events.is_empty():
		failures.append("Blackjack stand settlement did not leave dealer card animation events on the result surface.")
	var dealer_hole_reveal_found := false
	for settlement_event_value in settlement_deal_events:
		if typeof(settlement_event_value) != TYPE_DICTIONARY:
			continue
		var settlement_event: Dictionary = settlement_event_value
		if str(settlement_event.get("zone", "")) == "dealer" and int(settlement_event.get("card_index", -1)) == 1:
			dealer_hole_reveal_found = true
			break
	if not dealer_hole_reveal_found:
		failures.append("Blackjack settlement did not schedule a dealer hole-card reveal event.")
	var settlement_reveal_harness := SurfaceHarness.new()
	settlement_reveal_harness.setup(settle_anim_surface)
	settlement_reveal_harness.animation_active = true
	settlement_reveal_harness.animation_elapsed = 0.05
	if not bool(game.call("_card_waiting_for_deal_animation", settlement_reveal_harness, settle_anim_surface, "dealer", 0, 1)):
		failures.append("Blackjack settlement exposed the dealer hole card before the reveal animation.")
	var settle_deal_started_msec := 0
	var settle_payout_started_msec := 0
	var settle_payout_channel_found := false
	for channel_value in settle_anim_surface.get("surface_animation_channels", []):
		if typeof(channel_value) != TYPE_DICTIONARY:
			continue
		var settlement_channel: Dictionary = channel_value
		if str(settlement_channel.get("id", "")) == "blackjack_deal":
			settle_deal_started_msec = int(settlement_channel.get("started_msec", 0))
		elif str(settlement_channel.get("id", "")) == "blackjack_payout":
			settle_payout_channel_found = not str(settlement_channel.get("active_id", "")).is_empty()
			settle_payout_started_msec = int(settlement_channel.get("started_msec", 0))
	if not settle_payout_channel_found:
		failures.append("Blackjack result surface did not activate the settlement payout animation channel.")
	if settle_deal_started_msec > 0 and settle_payout_started_msec - settle_deal_started_msec < int(settle_anim_surface.get("deal_animation_duration_msec", 0)):
		failures.append("Blackjack payout animation started before the dealer reveal/deal sequence completed.")
	var clock_run_state: RunState = RunStateScript.new()
	clock_run_state.start_new("BLACKJACK-POST-DECISION-CLOCK")
	clock_run_state.bankroll = 1000
	var clock_environment := _surface_contract_environment()
	var clock_table := generated_state.duplicate(true)
	clock_table["patrons"] = []
	clock_table["side_bets"] = []
	clock_table["rules"] = {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": false, "max_split_hands": 4, "late_surrender": true}
	# Player 17 versus dealer 11 forces two visible dealer draws after Stand.
	clock_table["shoe"] = [
		{"rank": 10, "suit": 0}, {"rank": 6, "suit": 1},
		{"rank": 7, "suit": 2}, {"rank": 5, "suit": 3},
		{"rank": 4, "suit": 0}, {"rank": 3, "suit": 1},
	]
	clock_table["shoe_cursor"] = 0
	clock_environment["game_states"] = {"blackjack": clock_table}
	var clock_deal := game.surface_action_command("blackjack_deal", 0, false, {
		"selected_stake": 5,
		"surface_time_msec": 1000,
		"surface_presentation_time_msec": 9000,
	}, clock_run_state, clock_environment)
	var clock_deal_ui: Dictionary = (clock_deal.get("ui_state", {}) as Dictionary).duplicate(true)
	clock_deal_ui["surface_time_msec"] = 3000
	clock_deal_ui["surface_presentation_time_msec"] = 11000
	var clock_stand := game.surface_action_command("blackjack_stand", 0, true, clock_deal_ui, clock_run_state, clock_environment)
	if not bool(clock_stand.get("resolve", false)):
		failures.append("Blackjack post-decision clock fixture did not become settleable after the opening deal presentation.")
	var clock_result := game.resolve_with_context("play_basic", 5, clock_run_state, clock_environment, clock_run_state.create_rng("blackjack_post_decision_clock_resolve"), clock_stand.get("ui_state", {}))
	var clock_dealer: Array = clock_result.get("blackjack_dealer", []) if typeof(clock_result.get("blackjack_dealer", [])) == TYPE_ARRAY else []
	if clock_dealer.size() != 4:
		failures.append("Blackjack post-decision fixture did not execute both required dealer draws.")
	var clock_surface := game.surface_state(clock_run_state, clock_environment, {
		"surface_time_msec": 3000,
		"surface_presentation_time_msec": 11000,
	})
	var clock_events: Array = clock_surface.get("deal_animation_events", []) if typeof(clock_surface.get("deal_animation_events", [])) == TYPE_ARRAY else []
	var staged_dealer_indices: Array = []
	for event_value in clock_events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		if str(event.get("zone", "")) == "dealer":
			staged_dealer_indices.append(int(event.get("card_index", -1)))
	if not staged_dealer_indices.has(1) or not staged_dealer_indices.has(2) or not staged_dealer_indices.has(3):
		failures.append("Blackjack post-decision presentation omitted the hole reveal or a required dealer draw.")
	var clock_deal_channel: Dictionary = {}
	var clock_payout_channel: Dictionary = {}
	var clock_attention_channel: Dictionary = {}
	var clock_count_channel: Dictionary = {}
	for channel_value in clock_surface.get("surface_animation_channels", []):
		if typeof(channel_value) != TYPE_DICTIONARY:
			continue
		var channel: Dictionary = channel_value
		match str(channel.get("id", "")):
			"blackjack_deal":
				clock_deal_channel = channel
			"blackjack_payout":
				clock_payout_channel = channel
			"blackjack_attention":
				clock_attention_channel = channel
			"blackjack_count_rhythm":
				clock_count_channel = channel
	if str(clock_deal_channel.get("clock_source", "")) != "presentation" or int(clock_deal_channel.get("started_msec", 0)) != 11000:
		failures.append("Blackjack dealer cards were not authored on the live presentation clock at the decision boundary.")
	if str(clock_payout_channel.get("clock_source", "")) != "presentation":
		failures.append("Blackjack payout motion did not share the card presentation clock.")
	if str(clock_attention_channel.get("clock_source", "")) != "surface" or str(clock_count_channel.get("clock_source", "")) != "surface":
		failures.append("Blackjack Peek/count timing was not kept on the freeze-safe game-logic clock.")
	var clock_harness := SurfaceHarness.new()
	clock_harness.setup(clock_surface)
	clock_harness.animation_active = true
	clock_harness.animation_elapsed = 0.05
	if not bool(game.call("_card_waiting_for_deal_animation", clock_harness, clock_surface, "dealer", 0, 2)) \
			or not bool(game.call("_card_waiting_for_deal_animation", clock_harness, clock_surface, "dealer", 0, 3)):
		failures.append("Blackjack exposed final dealer cards before their post-decision deal events completed.")
	var sit_run_state: RunState = RunStateScript.new()
	sit_run_state.start_new("BLACKJACK-SITOUT-CONTRACT")
	sit_run_state.bankroll = 1000
	var sit_environment := _surface_contract_environment()
	var sit_table: Dictionary = game.generate_environment_state(sit_run_state, sit_environment, sit_run_state.create_rng("blackjack_sitout_table"))
	sit_environment["game_states"] = {"blackjack": sit_table}
	sit_run_state.current_environment = sit_environment.duplicate(true)
	var sit_result := game.resolve_with_context("play_basic", 0, sit_run_state, sit_environment, sit_run_state.create_rng("blackjack_sitout_resolve"), {"blackjack_sit_out": true})
	if not bool(sit_result.get("blackjack_sat_out", false)) or int(sit_result.get("total_wager", int(sit_result.get("stake", -1)))) != 0 or int(sit_result.get("bankroll_delta", 999)) != 0:
		failures.append("Blackjack sit-out hand did not consume a hand with zero wager and zero bankroll movement.")
	if not (sit_result.get("blackjack_player_hands", []) as Array).is_empty():
		failures.append("Blackjack sit-out hand dealt cards to the player despite no wager.")
	var sit_patron_hands: Array = sit_result.get("blackjack_patron_hands", []) as Array
	if sit_patron_hands.is_empty():
		failures.append("Blackjack sit-out hand did not deal hands to the table patrons.")
	for sit_patron_value in sit_patron_hands:
		if typeof(sit_patron_value) != TYPE_DICTIONARY:
			continue
		var sit_patron_hand: Dictionary = sit_patron_value
		var sit_patron_cards: Array = sit_patron_hand.get("cards", []) if typeof(sit_patron_hand.get("cards", [])) == TYPE_ARRAY else []
		if sit_patron_cards.size() < 2:
			failures.append("Blackjack sit-out patron hand had fewer than two cards.")
			break
	var sit_dealer_cards: Array = sit_result.get("blackjack_dealer", []) if typeof(sit_result.get("blackjack_dealer", [])) == TYPE_ARRAY else []
	if sit_dealer_cards.size() < 2:
		failures.append("Blackjack sit-out hand did not deal the dealer cards.")
	var sit_after_table: Dictionary = (sit_environment.get("game_states", {}) as Dictionary).get("blackjack", {})
	if int(sit_after_table.get("hands_played", 0)) <= 0 or int(sit_after_table.get("shoe_remaining", generated_shoe.size())) >= generated_shoe.size():
		failures.append("Blackjack sit-out hand did not advance table hand count and shoe state.")
	var sit_last_result: Dictionary = sit_after_table.get("last_result", {}) if typeof(sit_after_table.get("last_result", {})) == TYPE_DICTIONARY else {}
	if not (sit_last_result.get("player_hands", []) as Array).is_empty():
		failures.append("Blackjack sit-out last-result payload leaked a player hand.")
	if (sit_last_result.get("patron_hands", []) as Array).is_empty():
		failures.append("Blackjack sit-out last-result payload did not retain patron hands.")
	var timer_table: Dictionary = game.generate_environment_state(sit_run_state, sit_environment, sit_run_state.create_rng("blackjack_timer_table"))
	timer_table["last_result"] = {}
	timer_table["last_deal_started_msec"] = 0
	timer_table["last_deal_animation_events"] = []
	timer_table["table_round_timer_started_msec"] = Time.get_ticks_msec() - GameModule.TABLE_ROUND_START_DELAY_MSEC - 100
	var timer_environment := _surface_contract_environment()
	timer_environment["game_states"] = {"blackjack": timer_table}
	var timer_run_state: RunState = RunStateScript.new()
	timer_run_state.start_new("BLACKJACK-TIMER-CONTRACT")
	timer_run_state.bankroll = 1000
	timer_run_state.current_environment = timer_environment.duplicate(true)
	if not game.surface_needs_auto_tick({"surface_time_msec": Time.get_ticks_msec()}, timer_run_state, timer_environment):
		failures.append("Blackjack table timer did not request an auto hand when due.")
	var auto_hand := game.surface_auto_action_command({"surface_time_msec": Time.get_ticks_msec()}, timer_run_state, timer_environment, {})
	if str(auto_hand.get("action_id", "")) != "play_basic" or not bool(auto_hand.get("direct_resolve", false)) or not bool((auto_hand.get("ui_state", {}) as Dictionary).get("blackjack_sit_out", false)):
		failures.append("Blackjack timer auto command did not resolve a sit-out hand through basic play.")
	var tutorial_timer_run: RunState = RunStateScript.new()
	tutorial_timer_run.start_new("BLACKJACK-TUTORIAL-NO-TIMER", {"tutorial": true, "modifiers": {"tutorial_run": true}})
	tutorial_timer_run.current_environment = timer_environment.duplicate(true)
	var tutorial_timer_environment: Dictionary = tutorial_timer_run.current_environment
	var tutorial_timer_surface := game.surface_state(tutorial_timer_run, tutorial_timer_environment, {"surface_time_msec": Time.get_ticks_msec()})
	if not (tutorial_timer_surface.get("table_round_timer", {}) as Dictionary).is_empty():
		failures.append("Tutorial blackjack exposed the automated next-hand timer.")
	if game.surface_needs_auto_tick({"surface_time_msec": Time.get_ticks_msec()}, tutorial_timer_run, tutorial_timer_environment):
		failures.append("Tutorial blackjack requested an automatic idle deal.")
	if bool(game.surface_auto_action_command({"surface_time_msec": Time.get_ticks_msec()}, tutorial_timer_run, tutorial_timer_environment, {}).get("handled", false)):
		failures.append("Tutorial blackjack produced an automatic idle deal command.")
	var cheat_click := game.surface_action_command("blackjack_count_toggle", 0, false, deal_ui, run_state, environment)
	if str(cheat_click.get("action_id", "")) == "count_cards" or bool(cheat_click.get("resolve", false)):
		failures.append("Blackjack count opened a modal/resolve action instead of starting the live overlay.")
	var count_state: Dictionary = cheat_click.get("ui_state", {})
	var count_table: Dictionary = ((environment.get("game_states", {}) as Dictionary).get("blackjack", {}) as Dictionary)
	if not bool(count_table.get("counting_enabled", false)):
		failures.append("Blackjack count toggle did not persist counting-enabled state on the table.")
	var count_challenge: Dictionary = count_state.get("count_challenge", {})
	if (count_challenge.get("cards", []) as Array).is_empty():
		failures.append("Blackjack count did not create a visible-card count challenge.")
	if not count_challenge.has("icons") or not count_challenge.has("dealer_attention_risk") or not count_challenge.has("target_delta"):
		failures.append("Blackjack count challenge did not expose pulse-icon timing and attention fields.")
	var answer_state: Dictionary = count_state
	var count_icons: Array = count_challenge.get("icons", []) as Array
	if count_icons.is_empty():
		failures.append("Blackjack count did not create count pulse icons.")
	var countable_cards := 0
	for count_card_value in (count_challenge.get("cards", []) as Array):
		if typeof(count_card_value) == TYPE_DICTIONARY and _blackjack_test_count_delta([count_card_value]) != 0:
			countable_cards += 1
	if count_icons.size() != countable_cards:
		failures.append("Blackjack count created pulses for neutral cards or missed countable cards.")
	if not count_icons.is_empty() and typeof(count_icons[0]) == TYPE_DICTIONARY:
		# The rendered snapshot timestamp remains fixed between actions. Verify the
		# bubbles follow the canvas clock instead, without mutating/growing state.
		var first_count_icon: Dictionary = count_icons[0]
		var first_spawn := int(first_count_icon.get("spawn_msec", 0))
		var live_clock_surface := {
			"surface_time_msec": first_spawn - 1000,
			"count_challenge": count_challenge,
			"count_answered": false,
			"count_delta": 0,
			"recorded_running_count": 7,
		}
		var live_clock_harness := SurfaceHarness.new()
		live_clock_harness.setup(live_clock_surface)
		live_clock_harness.simulation_clock_msec = first_spawn + 10
		var challenge_before_draw := JSON.stringify(live_clock_surface.get("count_challenge", {}))
		game.call("_draw_count_challenge", live_clock_harness, live_clock_surface)
		var live_count_hit := _surface_harness_first_hit(live_clock_harness, "blackjack_count_icon", 0)
		if live_count_hit.is_empty() or not bool(live_count_hit.get("activate_on_hover", false)):
			failures.append("Blackjack count bubble animation did not expose a live hover-activation target from the canvas clock.")
		if not live_clock_harness.labels.has("COUNT +7"):
			failures.append("Blackjack count badge reset to the current hand delta instead of retaining the cumulative shoe count.")
		if JSON.stringify(live_clock_surface.get("count_challenge", {})) != challenge_before_draw:
			failures.append("Blackjack count rendering mutated or grew challenge state during a frame.")
	# Drive the live count entirely from the supplied surface clock. This is the
	# same clock Web actions and rendering receive, and protects deterministic
	# tests from accidental raw wall-clock reads in hit/miss paths.
	var test_now := 12000
	for i in range(count_icons.size()):
		if typeof(count_icons[i]) != TYPE_DICTIONARY:
			continue
		var icon: Dictionary = count_icons[i]
		if not icon.has("spawn_msec") or not icon.has("duration_msec") or not icon.has("count_value"):
			failures.append("Blackjack count pulse icon did not expose a timing target.")
		if int(icon.get("count_value", 0)) == 0:
			failures.append("Blackjack count created a clickable zero-value pulse.")
		icon["spawn_msec"] = test_now - 10
		icon["duration_msec"] = 5000
		count_icons[i] = icon
	count_challenge["icons"] = count_icons
	answer_state["count_challenge"] = count_challenge
	answer_state["surface_time_msec"] = test_now
	for i in range(count_icons.size()):
		var answer_click := game.surface_action_command("blackjack_count_icon", i, false, answer_state, run_state, environment)
		answer_state = answer_click.get("ui_state", {})
	var answered_resolved_times: Dictionary = (answer_state.get("count_challenge", {}) as Dictionary).get("resolved_icon_msec", {}) if typeof((answer_state.get("count_challenge", {}) as Dictionary).get("resolved_icon_msec", {})) == TYPE_DICTIONARY else {}
	if answered_resolved_times.size() < count_icons.size():
		failures.append("Blackjack clicked count pulses did not receive fade timestamps.")
	if bool(answer_state.get("count_answered", false)):
		failures.append("Blackjack count pulse hits finalized a live count instead of keeping the overlay active during play.")
	var answered_challenge: Dictionary = answer_state.get("count_challenge", {})
	if int(answered_challenge.get("dealer_attention_risk", 0)) != int(count_challenge.get("dealer_attention_risk", 0)):
		failures.append("Blackjack successful count pulse hits raised dealer suspicion.")
	var clean_count_result := game.resolve_with_context("count_cards", 1, run_state, environment, run_state.create_rng("blackjack_clean_count_contract"), answer_state)
	if int(clean_count_result.get("suspicion_delta", 0)) != 0:
		failures.append("Blackjack clean live count produced suspicion heat.")
	var dirty_count_state: Dictionary = count_state.duplicate(true)
	var dirty_count_challenge: Dictionary = dirty_count_state.get("count_challenge", {})
	var dirty_count_icons: Array = dirty_count_challenge.get("icons", []) as Array
	if not dirty_count_icons.is_empty() and typeof(dirty_count_icons[0]) == TYPE_DICTIONARY:
		var dirty_count_icon: Dictionary = dirty_count_icons[0]
		dirty_count_challenge["missed_icons"] = [str(dirty_count_icon.get("id", "forced_miss"))]
		dirty_count_challenge["dealer_attention_risk"] = 60
		dirty_count_state["count_challenge"] = dirty_count_challenge
		dirty_count_state["count_answered"] = true
		dirty_count_state["count_correct"] = false
		var dirty_count_result := game.resolve_with_context("count_cards", 1, run_state, environment, run_state.create_rng("blackjack_dirty_count_contract"), dirty_count_state)
		if int(dirty_count_result.get("suspicion_delta", 0)) < 14:
			failures.append("Blackjack inaccurate live count did not produce significant heat.")
	var miss_state: Dictionary = count_state.duplicate(true)
	var miss_challenge: Dictionary = miss_state.get("count_challenge", {})
	var miss_icons: Array = miss_challenge.get("icons", []) as Array
	if not miss_icons.is_empty() and typeof(miss_icons[0]) == TYPE_DICTIONARY:
		var miss_icon: Dictionary = miss_icons[0]
		miss_icon["spawn_msec"] = test_now - 5000
		miss_icon["duration_msec"] = 1
		miss_icons[0] = miss_icon
		miss_challenge["icons"] = miss_icons
		miss_state["count_challenge"] = miss_challenge
		miss_state["surface_time_msec"] = test_now
		if not game.surface_needs_auto_tick(miss_state, run_state, environment):
			failures.append("Blackjack live count did not request auto tick when a count symbol expired.")
		var miss_tick := game.surface_auto_action_command(miss_state, run_state, environment, {})
		var tick_state: Dictionary = miss_tick.get("ui_state", {})
		var tick_challenge: Dictionary = tick_state.get("count_challenge", {})
		if (_string_array(tick_challenge.get("missed_icons", []))).is_empty():
			failures.append("Blackjack live count auto tick did not persist missed count symbols.")
	var watched_peek_run_state: RunState = RunStateScript.new()
	watched_peek_run_state.start_new("BLACKJACK-WATCHED-PEEK-CONTRACT")
	var watched_peek_environment := _surface_contract_environment()
	var watched_peek_table := generated_state.duplicate(true)
	watched_peek_table["dealer_profile"] = {"attention_base": 100, "gaze_speed": 95, "blink_offset": 0, "tell": "locks onto your hands"}
	watched_peek_table["patrons"] = []
	watched_peek_table["side_bets"] = []
	watched_peek_environment["game_states"] = {"blackjack": watched_peek_table}
	watched_peek_run_state.current_environment = watched_peek_environment.duplicate(true)
	var watched_deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, watched_peek_run_state, watched_peek_environment)
	var watched_peek := game.surface_action_command("blackjack_peek", 0, false, watched_deal.get("ui_state", {}), watched_peek_run_state, watched_peek_environment)
	var watched_peek_ui: Dictionary = watched_peek.get("ui_state", {})
	if str(watched_peek.get("action_id", "")) != "peek_hole_card" or not bool(watched_peek.get("resolve", false)):
		failures.append("Blackjack watched peek did not resolve as an immediate high-risk cheat.")
	if not bool(watched_peek_ui.get("peek_caught_watching", false)) or bool(watched_peek_ui.get("dealer_hole_visible", false)):
		failures.append("Blackjack watched peek exposed the hole card instead of flagging the dealer confrontation.")
	var watched_peek_result := game.resolve_with_context("peek_hole_card", 0, watched_peek_run_state, watched_peek_environment, watched_peek_run_state.create_rng("blackjack_watched_peek_resolve"), watched_peek_ui)
	if not bool(watched_peek_result.get("blackjack_table_barred", false)):
		failures.append("Blackjack watched peek did not bar the player from the table.")
	if int(watched_peek_result.get("blackjack_confiscated_bet", 0)) <= 0 or int(watched_peek_result.get("bankroll_delta", 0)) >= 0:
		failures.append("Blackjack watched peek did not confiscate the current wager.")
	if int(watched_peek_result.get("suspicion_delta", 0)) < 60 or int(watched_peek_result.get("suspicion_delta", 0)) > 80:
		failures.append("Blackjack watched peek did not add the requested 60-80 local heat.")
	if watched_peek_run_state.run_status != RunState.RUN_STATUS_ACTIVE:
		failures.append("Blackjack watched peek ended the run instead of leaving other games playable.")
	var barred_table: Dictionary = ((watched_peek_environment.get("game_states", {}) as Dictionary).get("blackjack", {}) as Dictionary)
	if not bool(barred_table.get("barred", false)):
		failures.append("Blackjack watched peek did not persist the barred table state.")
	if not game.legal_actions(watched_peek_run_state, watched_peek_environment).is_empty() or not game.cheat_actions(watched_peek_run_state, watched_peek_environment).is_empty():
		failures.append("Blackjack barred table still exposed normal blackjack actions.")
	if game.wager_cost_for_context("play_basic", 5, watched_peek_run_state, watched_peek_environment, watched_peek_ui) != 0:
		failures.append("Blackjack barred table still reported a wager cost.")
	var barred_surface := game.surface_state(watched_peek_run_state, watched_peek_environment, {})
	if not bool(barred_surface.get("table_barred", false)) or bool(barred_surface.get("can_deal", true)) or bool(barred_surface.get("peek_available", true)):
		failures.append("Blackjack barred surface still exposed live table controls.")
	var barred_object_state := game.environment_object_state(watched_peek_run_state, watched_peek_environment)
	if str((barred_object_state.get("visual_state", {}) as Dictionary).get("status", "")) != "barred":
		failures.append("Blackjack barred table did not publish a barred environment object status.")
	var tutorial_peek_run: RunState = RunStateScript.new()
	tutorial_peek_run.start_new("BLACKJACK-TUTORIAL-PEEK-REPRIEVE", {"tutorial": true, "modifiers": {"tutorial_run": true}})
	var tutorial_peek_environment := _surface_contract_environment()
	# The reprieve is a Pal-table tutorial rule, not a global tutorial Blackjack
	# exemption. Model the production venue so this contract exercises that rule.
	tutorial_peek_environment["archetype_id"] = "small_underground_casino"
	var tutorial_peek_table := generated_state.duplicate(true)
	tutorial_peek_table["dealer_profile"] = {"attention_base": 100, "gaze_speed": 95, "blink_offset": 0, "tell": "locks onto your hands"}
	tutorial_peek_table["patrons"] = []
	tutorial_peek_table["side_bets"] = []
	tutorial_peek_environment["game_states"] = {"blackjack": tutorial_peek_table}
	tutorial_peek_run.current_environment = tutorial_peek_environment.duplicate(true)
	var tutorial_deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5, "surface_time_msec": 4000}, tutorial_peek_run, tutorial_peek_environment)
	var tutorial_deal_ui: Dictionary = tutorial_deal.get("ui_state", {})
	tutorial_deal_ui["surface_time_msec"] = 5000
	var tutorial_distraction := game.surface_action_command("blackjack_distraction", 0, false, tutorial_deal_ui, tutorial_peek_run, tutorial_peek_environment)
	var tutorial_distraction_ui: Dictionary = tutorial_distraction.get("ui_state", {})
	if int(tutorial_distraction_ui.get("dealer_lookaway_started_msec", -1)) != 5000:
		failures.append("Tutorial blackjack Peek window started from wall time instead of the pausable surface clock.")
	var frozen_peek_a := game.surface_state(tutorial_peek_run, tutorial_peek_environment, tutorial_distraction_ui)
	var frozen_peek_b := game.surface_state(tutorial_peek_run, tutorial_peek_environment, tutorial_distraction_ui)
	if int((frozen_peek_a.get("dealer_focus", {}) as Dictionary).get("lookaway_remaining_msec", -1)) != int((frozen_peek_b.get("dealer_focus", {}) as Dictionary).get("lookaway_remaining_msec", -2)):
		failures.append("Tutorial blackjack Peek time advanced while the supplied simulation clock was frozen.")
	var tutorial_bad_peek := game.surface_action_command("blackjack_peek", 0, false, tutorial_deal.get("ui_state", {}), tutorial_peek_run, tutorial_peek_environment)
	var tutorial_peek_result := game.resolve_with_context("peek_hole_card", 0, tutorial_peek_run, tutorial_peek_environment, tutorial_peek_run.create_rng("blackjack_tutorial_peek_reprieve"), tutorial_bad_peek.get("ui_state", {}))
	var tutorial_after_table: Dictionary = ((tutorial_peek_environment.get("game_states", {}) as Dictionary).get("blackjack", {}) as Dictionary)
	if not bool(tutorial_peek_result.get("blackjack_tutorial_peek_reprieve", false)) or bool(tutorial_peek_result.get("blackjack_table_barred", true)) or bool(tutorial_after_table.get("barred", true)):
		failures.append("The first caught tutorial Peek did not leave the blackjack table open through the dealer reprieve.")
	if int(tutorial_peek_result.get("bankroll_delta", -1)) != 0 \
			or not bool(tutorial_peek_result.get("preserve_surface_ui_state", false)) \
			or not bool((tutorial_peek_result.get("blackjack_surface_ui_state", {}) as Dictionary).get("peek_caught_watching", false)) \
			or (tutorial_peek_result.get("blackjack_surface_ui_state", {}) as Dictionary).get("player_hands", []).is_empty():
		failures.append("The tutorial Peek reprieve did not preserve the current hand without confiscating its wager twice.")
	if not bool(tutorial_peek_run.narrative_flags.get("tutorial_blackjack_peek_reprieve_used", false)):
		failures.append("Tutorial blackjack did not persist the one-time dealer warning marker.")
	var backoff_guard_run: RunState = RunStateScript.new()
	backoff_guard_run.start_new("BLACKJACK-TUTORIAL-REPRIEVE-BACKOFF-GUARD", {"tutorial": true, "modifiers": {"tutorial_run": true}})
	backoff_guard_run.current_environment = {
		"id": "blackjack_reprieve_backoff_guard",
		"display_name": "Pal's Tutorial Table",
		"archetype_id": "small_underground_casino",
		"game_states": {"blackjack": {"dealer_name": "Pal"}},
	}
	backoff_guard_run.suspicion["level"] = RunState.BLACKJACK_BACKOFF_HEAT
	var protected_backoff := backoff_guard_run.apply_blackjack_heat_backoff({
		"game_id": "blackjack",
		"action_id": "peek_hole_card",
		"blackjack_tutorial_peek_reprieve": true,
	})
	var protected_backoff_table: Dictionary = (backoff_guard_run.current_environment.get("game_states", {}) as Dictionary).get("blackjack", {})
	if not protected_backoff.is_empty() or bool(protected_backoff_table.get("barred", false)) or bool(protected_backoff_table.get("heat_backoff", false)):
		failures.append("RunState Heat backoff overrode a Blackjack tutorial Peek reprieve.")
	var normal_backoff := backoff_guard_run.apply_blackjack_heat_backoff({
		"game_id": "blackjack",
		"action_id": "peek_hole_card",
	})
	var normal_backoff_table: Dictionary = (backoff_guard_run.current_environment.get("game_states", {}) as Dictionary).get("blackjack", {})
	if normal_backoff.is_empty() or not bool(normal_backoff_table.get("barred", false)) or not bool(normal_backoff_table.get("heat_backoff", false)):
		failures.append("RunState Heat backoff accepted live tutorial eligibility without an emitted reprieve marker.")
	var normal_barred_snapshot := JSON.stringify(backoff_guard_run.current_environment)
	if not backoff_guard_run.apply_blackjack_heat_backoff({"game_id": "blackjack", "action_id": "peek_hole_card"}).is_empty() \
			or JSON.stringify(backoff_guard_run.current_environment) != normal_barred_snapshot:
		failures.append("Normal Blackjack Heat backoff lost idempotency after the first persistent bar.")
	var hostile_reprieve_cases := [
		{"id": "post_completion", "tutorial": true, "archetype_id": "small_underground_casino", "action_id": "peek_hole_card", "tutorial_count_completed": true},
		{"id": "non_tutorial", "tutorial": false, "archetype_id": "small_underground_casino", "action_id": "peek_hole_card", "tutorial_count_completed": false},
		{"id": "non_pal_venue", "tutorial": true, "archetype_id": "delta_queen", "action_id": "peek_hole_card", "tutorial_count_completed": false},
		{"id": "non_peek", "tutorial": true, "archetype_id": "small_underground_casino", "action_id": "play_basic", "tutorial_count_completed": false},
	]
	for hostile_case_value in hostile_reprieve_cases:
		var hostile_case: Dictionary = hostile_case_value
		var hostile_run: RunState = RunStateScript.new()
		var hostile_config := {"tutorial": true, "modifiers": {"tutorial_run": true}} if bool(hostile_case.get("tutorial", false)) else {}
		hostile_run.start_new("BLACKJACK-REPRIEVE-HOSTILE-%s" % str(hostile_case.get("id", "case")).to_upper(), hostile_config)
		hostile_run.current_environment = {
			"id": "blackjack_reprieve_hostile_%s" % str(hostile_case.get("id", "case")),
			"display_name": "Blackjack Reprieve Hostile Guard",
			"archetype_id": str(hostile_case.get("archetype_id", "")),
			"game_states": {"blackjack": {
				"dealer_name": "Guard Dealer",
				"tutorial_count_completed": bool(hostile_case.get("tutorial_count_completed", false)),
			}},
		}
		hostile_run.suspicion["level"] = RunState.BLACKJACK_BACKOFF_HEAT
		var hostile_result := {
			"game_id": "blackjack",
			"action_id": str(hostile_case.get("action_id", "")),
			"blackjack_tutorial_peek_reprieve": true,
		}
		var hostile_backoff := hostile_run.apply_blackjack_heat_backoff(hostile_result)
		var hostile_table: Dictionary = (hostile_run.current_environment.get("game_states", {}) as Dictionary).get("blackjack", {})
		if hostile_backoff.is_empty() or not bool(hostile_table.get("barred", false)) or not bool(hostile_table.get("heat_backoff", false)):
			failures.append("RunState trusted a hostile Blackjack tutorial reprieve marker for %s." % str(hostile_case.get("id", "case")))
		var barred_snapshot := JSON.stringify(hostile_run.current_environment)
		if not hostile_run.apply_blackjack_heat_backoff(hostile_result).is_empty() or JSON.stringify(hostile_run.current_environment) != barred_snapshot:
			failures.append("Blackjack Heat backoff lost idempotency after rejecting hostile reprieve case %s." % str(hostile_case.get("id", "case")))
	var second_tutorial_table := tutorial_peek_table.duplicate(true)
	second_tutorial_table["barred"] = false
	tutorial_peek_environment["game_states"] = {"blackjack": second_tutorial_table}
	var second_tutorial_deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5, "surface_time_msec": 8000}, tutorial_peek_run, tutorial_peek_environment)
	var second_tutorial_peek := game.surface_action_command("blackjack_peek", 0, false, second_tutorial_deal.get("ui_state", {}), tutorial_peek_run, tutorial_peek_environment)
	var second_tutorial_result := game.resolve_with_context("peek_hole_card", 0, tutorial_peek_run, tutorial_peek_environment, tutorial_peek_run.create_rng("blackjack_tutorial_peek_barred"), second_tutorial_peek.get("ui_state", {}))
	if bool(second_tutorial_result.get("blackjack_table_barred", true)) \
			or not bool(second_tutorial_result.get("blackjack_tutorial_peek_reprieve", false)):
		failures.append("A repeated bad Peek barred the tutorial table before the player completed the counting lesson.")
	var learned_tutorial_table := tutorial_peek_table.duplicate(true)
	learned_tutorial_table["barred"] = false
	learned_tutorial_table["tutorial_count_completed"] = true
	tutorial_peek_environment["game_states"] = {"blackjack": learned_tutorial_table}
	var learned_tutorial_deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5, "surface_time_msec": 12000}, tutorial_peek_run, tutorial_peek_environment)
	var learned_tutorial_peek := game.surface_action_command("blackjack_peek", 0, false, learned_tutorial_deal.get("ui_state", {}), tutorial_peek_run, tutorial_peek_environment)
	var learned_tutorial_result := game.resolve_with_context("peek_hole_card", 0, tutorial_peek_run, tutorial_peek_environment, tutorial_peek_run.create_rng("blackjack_tutorial_peek_after_count"), learned_tutorial_peek.get("ui_state", {}))
	if not bool(learned_tutorial_result.get("blackjack_table_barred", false)):
		failures.append("Tutorial blackjack kept protecting bad Peeks after the counting lesson was complete.")
	var cufflinks_run_state: RunState = RunStateScript.new()
	cufflinks_run_state.start_new("BLACKJACK-COOLERS-CUFFLINKS")
	cufflinks_run_state.add_item("coolers_cufflinks")
	var cufflinks_environment := _surface_contract_environment()
	var cufflinks_table := generated_state.duplicate(true)
	cufflinks_table["dealer_profile"] = {"attention_base": 100, "gaze_speed": 95, "blink_offset": 0, "tell": "locks onto your hands"}
	cufflinks_table["patrons"] = []
	cufflinks_table["side_bets"] = []
	cufflinks_environment["game_states"] = {"blackjack": cufflinks_table}
	cufflinks_run_state.current_environment = cufflinks_environment.duplicate(true)
	var cufflinks_deal: Dictionary = game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, cufflinks_run_state, cufflinks_environment)
	var cufflinks_peek: Dictionary = game.surface_action_command("blackjack_peek", 0, false, cufflinks_deal.get("ui_state", {}), cufflinks_run_state, cufflinks_environment)
	var cufflinks_result: Dictionary = game.resolve_with_context("peek_hole_card", 0, cufflinks_run_state, cufflinks_environment, cufflinks_run_state.create_rng("blackjack_cufflinks_peek_resolve"), cufflinks_peek.get("ui_state", {}))
	if int(cufflinks_result.get("suspicion_delta", -1)) != 0:
		failures.append("Cooler's Cufflinks did not fully absorb failed blackjack peek heat.")
	if not bool(cufflinks_result.get("blackjack_coolers_cufflinks_broke", false)):
		failures.append("Cooler's Cufflinks failed peek did not report the break event.")
	if cufflinks_run_state.inventory.has("coolers_cufflinks") or not cufflinks_run_state.inventory.has("broken_cufflinks"):
		failures.append("Cooler's Cufflinks did not turn into Broken Cufflinks after a failed peek.")
	var distract_click := game.surface_action_command("blackjack_distraction", 0, false, deal_ui, run_state, environment)
	var peek_click := game.surface_action_command("blackjack_peek", 0, false, distract_click.get("ui_state", {}), run_state, environment)
	if str(peek_click.get("action_kind", "")) != "cheat" or not bool(peek_click.get("preserve_surface_ui_state", false)) or not bool((peek_click.get("ui_state", {}) as Dictionary).get("dealer_hole_visible", false)):
		failures.append("Blackjack peek did not expose the dealer hole card after a distraction.")
	var successful_peek_result := game.resolve_with_context("peek_hole_card", 0, run_state, environment, run_state.create_rng("blackjack_successful_peek_preserves_hand"), peek_click.get("ui_state", {}))
	var successful_peek_state: Dictionary = successful_peek_result.get("blackjack_surface_ui_state", {}) if typeof(successful_peek_result.get("blackjack_surface_ui_state", {})) == TYPE_DICTIONARY else {}
	if not bool(successful_peek_result.get("preserve_surface_ui_state", false)) \
			or not bool(successful_peek_state.get("dealer_hole_visible", false)) \
			or (successful_peek_state.get("player_hands", []) as Array).is_empty():
		failures.append("A successful blackjack Peek discarded the active hand before Hit or Stand could conclude it.")
	var repeat_peek := game.surface_action_command("blackjack_peek", 0, false, peek_click.get("ui_state", {}), run_state, environment)
	if str(repeat_peek.get("action_id", "")) == "peek_hole_card":
		failures.append("Blackjack peek allowed a repeated hole-card cheat action.")
	var strategy_run_state: RunState = RunStateScript.new()
	strategy_run_state.start_new("BLACKJACK-STRATEGY-DEVIATION-CONTRACT")
	var strategy_environment := _surface_contract_environment()
	var strategy_table := generated_state.duplicate(true)
	strategy_table["shoe_cursor"] = 0
	strategy_table["patrons"] = []
	strategy_table["side_bets"] = []
	strategy_table["dealer_profile"] = {"attention_base": 10, "gaze_speed": 95, "blink_offset": 0, "tell": "tracks perfect deviations", "strategy_scrutiny": 18, "strategy_threshold": 2, "strategy_response": "both"}
	strategy_table["distractions"] = [{"id": "test_window", "label": "Test Window", "summary": "safe peek", "duration_msec": 4000, "cover": 20, "noise": 0}]
	strategy_table["shoe"] = [
		{"rank": 10, "suit": 0}, {"rank": 10, "suit": 1}, {"rank": 7, "suit": 2}, {"rank": 10, "suit": 3},
		{"rank": 2, "suit": 0}, {"rank": 5, "suit": 1}, {"rank": 6, "suit": 2}, {"rank": 8, "suit": 3}
	]
	strategy_environment["game_states"] = {"blackjack": strategy_table}
	var strategy_deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, strategy_run_state, strategy_environment)
	var strategy_distraction := game.surface_action_command("blackjack_distraction", 0, false, strategy_deal.get("ui_state", {}), strategy_run_state, strategy_environment)
	var strategy_peek := game.surface_action_command("blackjack_peek", 0, false, strategy_distraction.get("ui_state", {}), strategy_run_state, strategy_environment)
	var strategy_hit := game.surface_action_command("blackjack_hit", 0, false, strategy_peek.get("ui_state", {}), strategy_run_state, strategy_environment)
	var strategy_hit_ui: Dictionary = strategy_hit.get("ui_state", {})
	if not bool(strategy_hit_ui.get("strategy_confronted", false)) or (strategy_hit_ui.get("strategy_deviation_events", []) as Array).is_empty():
		failures.append("Blackjack did not flag a beneficial off-book hit after a cheated dealer peek.")
	var strategy_focus_surface := game.surface_state(strategy_run_state, strategy_environment, strategy_hit_ui)
	if int((strategy_focus_surface.get("dealer_focus", {}) as Dictionary).get("strategy_pressure", 0)) <= 0:
		failures.append("Blackjack strategy deviation did not increase dealer watch pressure during the hand.")
	var strategy_stand := game.surface_action_command("blackjack_stand", 0, false, strategy_hit_ui, strategy_run_state, strategy_environment)
	var strategy_result := game.resolve_with_context("play_basic", 5, strategy_run_state, strategy_environment, strategy_run_state.create_rng("blackjack_strategy_deviation_resolve"), strategy_stand.get("ui_state", {}))
	if not bool(strategy_result.get("blackjack_strategy_confronted", false)) or int(strategy_result.get("suspicion_delta", 0)) <= 0:
		failures.append("Blackjack strategy deviation confrontation did not resolve into heat.")
	if int(strategy_result.get("suspicion_delta", 0)) < 12:
		failures.append("Blackjack hole-card-informed strategy deviation did not receive significant heat.")
	var strategy_after_table: Dictionary = ((strategy_environment.get("game_states", {}) as Dictionary).get("blackjack", {}) as Dictionary)
	if int(strategy_after_table.get("strategy_watch_pressure", 0)) <= 0:
		failures.append("Blackjack strategy deviation did not persist dealer watch pressure on the table.")
	var ordinary_strategy_run: RunState = RunStateScript.new()
	ordinary_strategy_run.start_new("BLACKJACK-ORDINARY-STRATEGY-MISTAKE")
	var ordinary_strategy_environment := _surface_contract_environment()
	var ordinary_strategy_table := generated_state.duplicate(true)
	ordinary_strategy_table["patrons"] = []
	ordinary_strategy_table["side_bets"] = []
	ordinary_strategy_table["dealer_profile"] = {"attention_base": 10, "gaze_speed": 95, "blink_offset": 0, "strategy_scrutiny": 18, "strategy_threshold": 2, "strategy_response": "both"}
	ordinary_strategy_environment["game_states"] = {"blackjack": ordinary_strategy_table}
	ordinary_strategy_run.current_environment = ordinary_strategy_environment.duplicate(true)
	var ordinary_ui := {
		"selected_stake": 5,
		"locked_stake": 5,
		"player_hands": [{"cards": [{"rank": 10, "suit": 0}, {"rank": 6, "suit": 1}], "stood": false, "wager_multiplier": 1}],
		"dealer_cards": [{"rank": 10, "suit": 2}, {"rank": 7, "suit": 3}],
		"initial_player_cards": [{"rank": 10, "suit": 0}, {"rank": 6, "suit": 1}],
		"initial_dealer_cards": [{"rank": 10, "suit": 2}, {"rank": 7, "suit": 3}],
		"active_hand_index": 0,
		"cards_consumed": 4,
		"strategy_deviation_events": [{"chosen": "stand", "recommended": "surrender", "score": 1, "information_source": "ordinary"}],
		"strategy_deviation_score": 1,
		"strategy_attention_boost": 1,
		"strategy_confronted": false,
	}
	var ordinary_strategy_result := game.resolve_with_context("play_basic", 5, ordinary_strategy_run, ordinary_strategy_environment, ordinary_strategy_run.create_rng("blackjack_ordinary_strategy_resolve"), ordinary_ui)
	if int(ordinary_strategy_result.get("suspicion_delta", -1)) < 0 or int(ordinary_strategy_result.get("suspicion_delta", 99)) > 3:
		failures.append("Blackjack ordinary strategy mistake was punished with too much heat.")
	var ordinary_strategy_after: Dictionary = ((ordinary_strategy_environment.get("game_states", {}) as Dictionary).get("blackjack", {}) as Dictionary)
	if int(ordinary_strategy_after.get("strategy_deviation_strikes", 0)) != 0:
		failures.append("Blackjack ordinary strategy mistake incorrectly built persistent advantage-play strikes.")
	var count_advantage_run: RunState = RunStateScript.new()
	count_advantage_run.start_new("BLACKJACK-COUNT-INFORMED-STRATEGY")
	var count_advantage_environment := _surface_contract_environment()
	var count_advantage_table := generated_state.duplicate(true)
	count_advantage_table["patrons"] = []
	count_advantage_table["side_bets"] = []
	count_advantage_table["recorded_running_count"] = 4
	count_advantage_environment["game_states"] = {"blackjack": count_advantage_table}
	count_advantage_run.current_environment = count_advantage_environment.duplicate(true)
	var count_advantage_ui: Dictionary = ordinary_ui.duplicate(true)
	count_advantage_ui["counting_enabled"] = true
	count_advantage_ui["count_attempted"] = true
	count_advantage_ui["count_answered"] = true
	count_advantage_ui["count_correct"] = true
	count_advantage_ui["count_delta"] = 0
	count_advantage_ui["count_challenge"] = {
		"icons": [{"id": "count_advantage_probe", "count_value": 1}],
		"clicked_icons": ["count_advantage_probe"],
		"missed_icons": [],
		"bad_hits": 0,
		"target_delta": 1,
		"recorded_delta": 1,
		"tolerance": 0,
	}
	count_advantage_ui["strategy_deviation_events"] = [{"chosen": "stand", "recommended": "hit", "score": 2, "information_source": "count"}]
	count_advantage_ui["strategy_deviation_score"] = 2
	count_advantage_ui["strategy_attention_boost"] = 12
	var count_advantage_result := game.resolve_with_context("play_basic", 5, count_advantage_run, count_advantage_environment, count_advantage_run.create_rng("blackjack_count_advantage_resolve"), count_advantage_ui)
	if int(count_advantage_result.get("suspicion_delta", 0)) < 14:
		failures.append("Blackjack count-informed strategy deviation did not receive significant heat.")
	var count_advantage_after: Dictionary = ((count_advantage_environment.get("game_states", {}) as Dictionary).get("blackjack", {}) as Dictionary)
	if int(count_advantage_after.get("strategy_deviation_strikes", 0)) < 2:
		failures.append("Blackjack count-informed strategy deviation did not build persistent advantage-play scrutiny.")
	var triple_distraction_environment := _surface_contract_environment()
	var triple_distraction_table := generated_state.duplicate(true)
	triple_distraction_table["distractions"] = [
		{"id": "first", "label": "First", "summary": "test", "duration_msec": 2400, "cover": 4, "noise": 1},
		{"id": "second", "label": "Second", "summary": "test", "duration_msec": 2400, "cover": 4, "noise": 1},
		{"id": "third", "label": "Third", "summary": "test", "duration_msec": 2400, "cover": 4, "noise": 1},
	]
	triple_distraction_environment["game_states"] = {"blackjack": triple_distraction_table}
	var third_distraction := game.surface_action_command("blackjack_distraction", 2, false, {}, run_state, triple_distraction_environment)
	if not bool(third_distraction.get("handled", false)) or str((third_distraction.get("ui_state", {}) as Dictionary).get("dealer_distraction_id", "")) != "third":
		failures.append("Blackjack did not handle the third generated table distraction.")

	var bust_run_state: RunState = RunStateScript.new()
	bust_run_state.start_new("BLACKJACK-BUST-CONTRACT")
	var bust_environment := _surface_contract_environment()
	var bust_table := generated_state.duplicate(true)
	bust_table["shoe_cursor"] = 0
	bust_table["patrons"] = []
	bust_table["side_bets"] = []
	bust_table["rules"] = {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4}
	bust_table["shoe"] = [
		{"rank": 10, "suit": 0}, {"rank": 9, "suit": 2}, {"rank": 6, "suit": 1}, {"rank": 7, "suit": 3},
		{"rank": 10, "suit": 2}, {"rank": 5, "suit": 1}, {"rank": 4, "suit": 0}, {"rank": 3, "suit": 2}
	]
	bust_environment["game_states"] = {"blackjack": bust_table}
	var bust_deal := game.surface_action_command("blackjack_deal", 0, false, {}, bust_run_state, bust_environment)
	var bust_ui: Dictionary = bust_deal.get("ui_state", {})
	var bust_hit := game.surface_action_command("blackjack_hit", 0, false, bust_ui, bust_run_state, bust_environment)
	if not bool(bust_hit.get("resolve", false)):
		failures.append("Blackjack bust hit did not auto-resolve the completed busted hand.")
	if bool(bust_hit.get("preserve_surface_ui_state", false)):
		failures.append("Blackjack bust hit preserved stale busted-hand UI state after resolution.")
	bust_ui = bust_hit.get("ui_state", {})
	var bust_surface := game.surface_state(bust_run_state, bust_environment, bust_ui)
	if bool(bust_surface.get("can_hit", true)) or bool(bust_surface.get("can_stand", true)):
		failures.append("Blackjack busted hand still exposed hit or stand controls.")
	if str(bust_surface.get("table_notice", "")).to_lower().find("bust") < 0:
		failures.append("Blackjack busted hand did not expose a clear bust table notice.")
	var bust_result := game.resolve_with_context("play_basic", 5, bust_run_state, bust_environment, bust_run_state.create_rng("blackjack_bust_resolve"), bust_ui)
	var bust_hands: Array = bust_result.get("blackjack_hand_results", []) as Array
	if bust_hands.is_empty() or str((bust_hands[0] as Dictionary).get("outcome", "")) != "bust":
		failures.append("Blackjack bust resolve did not settle the hand as a bust.")
	if (bust_result.get("blackjack_dealer", []) as Array).size() <= 2:
		failures.append("Blackjack bust loss ended before the dealer completed the hand.")

	var natural_run_state: RunState = RunStateScript.new()
	natural_run_state.start_new("BLACKJACK-NATURAL-CONTRACT")
	var natural_environment := _surface_contract_environment()
	var natural_table := generated_state.duplicate(true)
	natural_table["shoe_cursor"] = 0
	natural_table["patrons"] = []
	natural_table["side_bets"] = []
	natural_table["rules"] = {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}
	natural_table["shoe"] = [
		{"rank": 14, "suit": 0}, {"rank": 9, "suit": 2}, {"rank": 13, "suit": 1}, {"rank": 7, "suit": 3},
		{"rank": 5, "suit": 0}, {"rank": 6, "suit": 1}, {"rank": 8, "suit": 2}, {"rank": 4, "suit": 3}
	]
	natural_environment["game_states"] = {"blackjack": natural_table}
	var natural_deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, natural_run_state, natural_environment)
	var natural_ui: Dictionary = natural_deal.get("ui_state", {})
	var natural_settle := game.surface_action_command("blackjack_deal", 0, false, natural_ui, natural_run_state, natural_environment)
	natural_ui = natural_settle.get("ui_state", {})
	var natural_result := game.resolve_with_context("play_basic", 5, natural_run_state, natural_environment, natural_run_state.create_rng("blackjack_natural_resolve"), natural_ui)
	var natural_hands: Array = natural_result.get("blackjack_hand_results", []) as Array
	if natural_hands.is_empty() or str((natural_hands[0] as Dictionary).get("outcome", "")) != "blackjack":
		failures.append("Blackjack natural did not settle as a 3:2 blackjack.")
	if (natural_result.get("blackjack_dealer", []) as Array).size() < 2:
		failures.append("Blackjack natural did not preserve the dealer showdown cards.")
	if int(natural_result.get("suspicion_delta", 0)) != 0 or bool(natural_result.get("blackjack_cheat_caught", false)):
		failures.append("Blackjack legal settlement reveal was incorrectly treated as hole-card cheating.")
	var natural_post_surface := game.surface_state(natural_run_state, natural_environment, {})
	var natural_last_result: Dictionary = natural_post_surface.get("last_result", {})
	if (natural_last_result.get("player_hands", []) as Array).is_empty() or (natural_last_result.get("dealer_cards", []) as Array).is_empty():
		failures.append("Blackjack settlement payload did not preserve final showdown cards.")
	if str(natural_last_result.get("payout_animation_id", "")).is_empty():
		failures.append("Blackjack settlement payload did not expose a payout animation id.")
	if not bool(natural_post_surface.get("showdown_active", false)) or (natural_post_surface.get("showdown_player_hands", []) as Array).is_empty():
		failures.append("Blackjack post-settle surface did not expose the resolved showdown.")
	if str(natural_post_surface.get("table_notice", "")).find("Dealer") < 0:
		failures.append("Blackjack post-settle notice did not summarize the dealer-vs-player result.")
	var payout_channel_found := false
	for channel_value in natural_post_surface.get("surface_animation_channels", []):
		if typeof(channel_value) == TYPE_DICTIONARY and str((channel_value as Dictionary).get("id", "")) == "blackjack_payout":
			payout_channel_found = not str((channel_value as Dictionary).get("active_id", "")).is_empty()
	if not payout_channel_found:
		failures.append("Blackjack post-settle surface did not activate the payout animation channel.")

	var surrender_run_state: RunState = RunStateScript.new()
	surrender_run_state.start_new("BLACKJACK-SURRENDER-CONTRACT")
	var surrender_environment := _surface_contract_environment()
	var surrender_table := generated_state.duplicate(true)
	surrender_table["shoe_cursor"] = 0
	surrender_table["patrons"] = []
	surrender_table["side_bets"] = []
	surrender_table["rules"] = {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}
	surrender_table["shoe"] = [
		{"rank": 10, "suit": 0}, {"rank": 9, "suit": 2}, {"rank": 6, "suit": 1}, {"rank": 7, "suit": 3},
		{"rank": 5, "suit": 0}, {"rank": 8, "suit": 1}, {"rank": 4, "suit": 2}, {"rank": 3, "suit": 3}
	]
	surrender_environment["game_states"] = {"blackjack": surrender_table}
	var surrender_deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, surrender_run_state, surrender_environment)
	var surrender_ui: Dictionary = surrender_deal.get("ui_state", {})
	var surrender_surface := game.surface_state(surrender_run_state, surrender_environment, surrender_ui)
	if not bool(surrender_surface.get("can_surrender", false)):
		failures.append("Blackjack did not expose late surrender on an eligible opening hand.")
	var surrender_click := game.surface_action_command("blackjack_surrender", 0, false, surrender_ui, surrender_run_state, surrender_environment)
	if not bool(surrender_click.get("resolve", false)):
		failures.append("Blackjack surrender did not immediately resolve the surrendered hand.")
	surrender_ui = surrender_click.get("ui_state", {})
	var surrender_result := game.resolve_with_context("play_basic", 5, surrender_run_state, surrender_environment, surrender_run_state.create_rng("blackjack_surrender_resolve"), surrender_ui)
	var surrender_hands: Array = surrender_result.get("blackjack_hand_results", []) as Array
	if surrender_hands.is_empty() or str((surrender_hands[0] as Dictionary).get("outcome", "")) != "surrender" or int((surrender_hands[0] as Dictionary).get("bankroll_delta", 0)) != -3:
		failures.append("Blackjack surrender did not settle as a half-wager loss.")
	if (surrender_result.get("blackjack_dealer", []) as Array).size() != 2:
		failures.append("Blackjack surrender incorrectly made the dealer draw extra cards.")

	var marked_surrender_run_state: RunState = RunStateScript.new()
	marked_surrender_run_state.start_new("BLACKJACK-MARKED-LEGAL-LOSS")
	marked_surrender_run_state.add_item("marked_cards")
	var marked_surrender_environment := _surface_contract_environment()
	var marked_surrender_table := generated_state.duplicate(true)
	marked_surrender_table["shoe_cursor"] = 0
	marked_surrender_table["patrons"] = []
	marked_surrender_table["side_bets"] = []
	marked_surrender_table["rules"] = {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}
	marked_surrender_table["shoe"] = [
		{"rank": 10, "suit": 0}, {"rank": 9, "suit": 2}, {"rank": 6, "suit": 1}, {"rank": 7, "suit": 3},
		{"rank": 5, "suit": 0}, {"rank": 8, "suit": 1}, {"rank": 4, "suit": 2}, {"rank": 3, "suit": 3}
	]
	marked_surrender_environment["game_states"] = {"blackjack": marked_surrender_table}
	var marked_surrender_deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, marked_surrender_run_state, marked_surrender_environment)
	var marked_surrender_click := game.surface_action_command("blackjack_surrender", 0, false, marked_surrender_deal.get("ui_state", {}), marked_surrender_run_state, marked_surrender_environment)
	var marked_surrender_result := game.resolve_with_context("play_basic", 5, marked_surrender_run_state, marked_surrender_environment, marked_surrender_run_state.create_rng("blackjack_marked_surrender_resolve"), marked_surrender_click.get("ui_state", {}))
	if int(marked_surrender_result.get("bankroll_delta", 0)) != -3 or int(marked_surrender_result.get("blackjack_main_delta", 0)) != -3:
		failures.append("Blackjack marked cards reduced a legal reveal loss without an actual peek cheat.")

	var all_in_run_state: RunState = RunStateScript.new()
	all_in_run_state.start_new("BLACKJACK-UPFRONT-ALL-IN")
	all_in_run_state.change_bankroll(-90)
	var all_in_environment := _surface_contract_environment()
	var all_in_table := generated_state.duplicate(true)
	all_in_table["shoe_cursor"] = 0
	all_in_table["patrons"] = []
	all_in_table["side_bets"] = []
	all_in_table["rules"] = {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}
	all_in_table["shoe"] = [
		{"rank": 10, "suit": 0}, {"rank": 10, "suit": 1}, {"rank": 6, "suit": 2}, {"rank": 9, "suit": 3},
		{"rank": 5, "suit": 0}, {"rank": 8, "suit": 1}, {"rank": 4, "suit": 2}, {"rank": 3, "suit": 3}
	]
	all_in_environment["game_states"] = {"blackjack": all_in_table}
	var all_in_deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 10}, all_in_run_state, all_in_environment)
	if str(all_in_deal.get("action_id", "")) != "blackjack_place_bet":
		failures.append("Blackjack all-in opening hand did not route through the upfront wager placement action.")
	var all_in_bet := game.resolve_with_context("blackjack_place_bet", 10, all_in_run_state, all_in_environment, all_in_run_state.create_rng("blackjack_all_in_bet"), all_in_deal.get("ui_state", {}))
	var all_in_bet_ui: Dictionary = all_in_bet.get("ui_state", {})
	if all_in_run_state.bankroll != 0:
		failures.append("Blackjack all-in opening wager did not debit bankroll before hand settlement.")
	if all_in_run_state.is_terminal():
		failures.append("Blackjack all-in opening wager ended the run before the unsettled hand resolved.")
	if not bool(all_in_bet.get("defer_bankroll_zero_failure", false)):
		failures.append("Blackjack all-in opening wager did not defer bankroll-zero failure during the live hand.")
	if int(all_in_bet.get("blackjack_wager_debited", 0)) != 10:
		failures.append("Blackjack all-in opening wager did not report the debited stake.")
	if (all_in_bet_ui.get("player_hands", []) as Array).is_empty():
		failures.append("Blackjack all-in upfront wager did not keep the dealt hand in surface state.")
	var all_in_stand := game.surface_action_command("blackjack_stand", 0, true, all_in_bet_ui, all_in_run_state, all_in_environment)
	var all_in_result := game.resolve_with_context("play_basic", 10, all_in_run_state, all_in_environment, all_in_run_state.create_rng("blackjack_all_in_settle"), all_in_stand.get("ui_state", {}))
	if int(all_in_result.get("blackjack_wager_debited", 0)) != 10:
		failures.append("Blackjack all-in settlement did not recognize the upfront-debited wager.")
	if int(all_in_result.get("bankroll_delta", 999)) != 0:
		failures.append("Blackjack all-in losing settlement charged the already-debited wager again.")
	if all_in_run_state.bankroll != 0:
		failures.append("Blackjack all-in losing settlement left an unexpected bankroll value.")
	if not all_in_run_state.is_terminal() or all_in_run_state.run_failure_reason != RunState.FAILURE_BANKROLL_ZERO:
		failures.append("Blackjack all-in losing settlement did not fail the run after the unresolved hand completed at zero bankroll.")

	var double_prompt_run_state: RunState = RunStateScript.new()
	double_prompt_run_state.start_new("BLACKJACK-DOUBLE-NOT-ALL-IN")
	double_prompt_run_state.change_bankroll(-68)
	var double_prompt_environment := _surface_contract_environment()
	var double_prompt_table := generated_state.duplicate(true)
	double_prompt_table["shoe_cursor"] = 0
	double_prompt_table["patrons"] = []
	double_prompt_table["side_bets"] = []
	double_prompt_table["rules"] = {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}
	double_prompt_table["shoe"] = [
		{"rank": 10, "suit": 0}, {"rank": 9, "suit": 1}, {"rank": 6, "suit": 2}, {"rank": 7, "suit": 3},
		{"rank": 2, "suit": 0}, {"rank": 8, "suit": 1}, {"rank": 4, "suit": 2}, {"rank": 3, "suit": 3}
	]
	double_prompt_environment["game_states"] = {"blackjack": double_prompt_table}
	var double_prompt_deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 11}, double_prompt_run_state, double_prompt_environment)
	var double_prompt_bet := game.resolve_with_context("blackjack_place_bet", 11, double_prompt_run_state, double_prompt_environment, double_prompt_run_state.create_rng("blackjack_double_prompt_bet"), double_prompt_deal.get("ui_state", {}))
	var double_prompt_bet_ui: Dictionary = double_prompt_bet.get("ui_state", {})
	if double_prompt_run_state.bankroll != 21:
		failures.append("Blackjack double prompt fixture did not leave $21 after the opening wager.")
	var double_prompt_command := game.surface_action_command("blackjack_double", 0, false, double_prompt_bet_ui, double_prompt_run_state, double_prompt_environment)
	var double_prompt_ui: Dictionary = double_prompt_command.get("ui_state", {})
	var double_prompt_remaining_cost := game.wager_cost_for_context("play_basic", 11, double_prompt_run_state, double_prompt_environment, double_prompt_ui)
	if double_prompt_remaining_cost != 11:
		failures.append("Blackjack double reported total wager instead of unpaid extra wager; expected 11, got %d." % double_prompt_remaining_cost)
	if double_prompt_run_state.bankroll - double_prompt_remaining_cost <= 0:
		failures.append("Blackjack double would show all-in confirmation despite cash remaining after the extra wager.")

	var split_run_state: RunState = RunStateScript.new()
	split_run_state.start_new("BLACKJACK-SPLIT-CONTRACT")
	var split_environment := _surface_contract_environment()
	var forced_table := generated_state.duplicate(true)
	forced_table["shoe_cursor"] = 0
	forced_table["patrons"] = [
		{"id": "patron_test_0", "name": "Nix", "seat": 0, "temper": "careless", "watching": true, "snitch_risk": 10},
		{"id": "patron_test_1", "name": "Vale", "seat": 1, "temper": "careful", "watching": true, "snitch_risk": 12},
	]
	forced_table["side_bets"] = [
		{"id": "perfect_pairs", "label": "Perfect Pairs", "summary": "Pair first two cards"},
		{"id": "insurance", "label": "Insurance", "summary": "Dealer blackjack pays 2:1"},
	]
	forced_table["rules"] = {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4}
	forced_table["shoe"] = [
		{"rank": 8, "suit": 0}, {"rank": 5, "suit": 2}, {"rank": 8, "suit": 1}, {"rank": 6, "suit": 3},
		{"rank": 10, "suit": 0}, {"rank": 2, "suit": 1}, {"rank": 9, "suit": 2}, {"rank": 3, "suit": 0},
		{"rank": 7, "suit": 1}, {"rank": 10, "suit": 2}, {"rank": 6, "suit": 0}, {"rank": 4, "suit": 3},
		{"rank": 13, "suit": 0}, {"rank": 12, "suit": 2}, {"rank": 11, "suit": 1}, {"rank": 9, "suit": 3}
	]
	split_environment["game_states"] = {"blackjack": forced_table}
	var forced_deal := game.surface_action_command("blackjack_deal", 0, false, {}, split_run_state, split_environment)
	var forced_deal_ui: Dictionary = forced_deal.get("ui_state", {})
	var split_surface := game.surface_state(split_run_state, split_environment, forced_deal_ui)
	if not bool(split_surface.get("can_split", false)):
		failures.append("Blackjack forced pair surface did not allow splitting.")
	var late_side_bet_click := game.surface_action_command("blackjack_side_bet", 0, false, forced_deal_ui, split_run_state, split_environment)
	if (late_side_bet_click.get("ui_state", {}) as Dictionary).get("blackjack_side_bets", []) != forced_deal_ui.get("blackjack_side_bets", []):
		failures.append("Blackjack allowed a non-insurance side bet to be changed after cards were dealt.")
	for side_bet_value in (split_surface.get("side_bets_available", []) as Array):
		if typeof(side_bet_value) == TYPE_DICTIONARY and str((side_bet_value as Dictionary).get("id", "")) == "insurance":
			failures.append("Blackjack exposed insurance when the dealer upcard was not an ace.")
	var forced_count_click := game.surface_action_command("blackjack_count_toggle", 0, false, forced_deal_ui, split_run_state, split_environment)
	var forced_count_state: Dictionary = forced_count_click.get("ui_state", {})
	var forced_count_challenge: Dictionary = forced_count_state.get("count_challenge", {})
	var forced_count_cards: Array = forced_count_challenge.get("cards", []) as Array
	if int(forced_count_challenge.get("target_delta", 999)) != _blackjack_test_count_delta(forced_count_cards):
		failures.append("Blackjack count challenge did not use all visible forced-table cards.")
	if forced_count_cards.size() <= 3:
		failures.append("Blackjack count challenge did not include other patron hands.")
	var forced_count_has_patron := false
	for forced_card_value in forced_count_cards:
		if typeof(forced_card_value) == TYPE_DICTIONARY and str((forced_card_value as Dictionary).get("_count_source_key", "")).begins_with("patron:"):
			forced_count_has_patron = true
	if not forced_count_has_patron:
		failures.append("Blackjack count challenge did not tag patron cards as count sources.")

	var ten_split_run_state: RunState = RunStateScript.new()
	ten_split_run_state.start_new("BLACKJACK-TEN-SPLIT-CONTRACT")
	var ten_split_environment := _surface_contract_environment()
	var ten_split_table := generated_state.duplicate(true)
	ten_split_table["shoe_cursor"] = 0
	ten_split_table["patrons"] = []
	ten_split_table["side_bets"] = []
	ten_split_table["rules"] = {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}
	ten_split_table["shoe"] = [
		{"rank": 10, "suit": 0}, {"rank": 5, "suit": 2}, {"rank": 13, "suit": 1}, {"rank": 6, "suit": 3},
		{"rank": 3, "suit": 0}, {"rank": 4, "suit": 1}, {"rank": 8, "suit": 2}, {"rank": 2, "suit": 3}
	]
	ten_split_environment["game_states"] = {"blackjack": ten_split_table}
	var ten_split_deal := game.surface_action_command("blackjack_deal", 0, false, {}, ten_split_run_state, ten_split_environment)
	var ten_split_surface := game.surface_state(ten_split_run_state, ten_split_environment, ten_split_deal.get("ui_state", {}))
	if not bool(ten_split_surface.get("can_split", false)):
		failures.append("Blackjack did not allow splitting two ten-value cards.")

	var insurance_run_state: RunState = RunStateScript.new()
	insurance_run_state.start_new("BLACKJACK-INSURANCE-CONTRACT")
	var insurance_environment := _surface_contract_environment()
	var insurance_table := generated_state.duplicate(true)
	insurance_table["shoe_cursor"] = 0
	insurance_table["patrons"] = []
	insurance_table["side_bets"] = [{"id": "insurance", "label": "Insurance", "summary": "Dealer blackjack pays 2:1"}]
	insurance_table["rules"] = {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}
	insurance_table["shoe"] = [
		{"rank": 10, "suit": 0}, {"rank": 14, "suit": 2}, {"rank": 9, "suit": 1}, {"rank": 6, "suit": 3},
		{"rank": 5, "suit": 0}, {"rank": 7, "suit": 1}, {"rank": 4, "suit": 2}, {"rank": 3, "suit": 3}
	]
	insurance_environment["game_states"] = {"blackjack": insurance_table}
	var insurance_deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 10}, insurance_run_state, insurance_environment)
	var insurance_ui: Dictionary = insurance_deal.get("ui_state", {})
	var insurance_surface := game.surface_state(insurance_run_state, insurance_environment, insurance_ui)
	if (insurance_surface.get("side_bets_available", []) as Array).is_empty():
		failures.append("Blackjack did not expose insurance on a dealer ace upcard.")
	var insurance_click := game.surface_action_command("blackjack_side_bet", 0, false, insurance_ui, insurance_run_state, insurance_environment)
	insurance_ui = insurance_click.get("ui_state", {})
	var insurance_stand := game.surface_action_command("blackjack_stand", 0, false, insurance_ui, insurance_run_state, insurance_environment)
	insurance_ui = insurance_stand.get("ui_state", {})
	var insurance_result := game.resolve_with_context("play_basic", 10, insurance_run_state, insurance_environment, insurance_run_state.create_rng("blackjack_insurance_resolve"), insurance_ui)
	var insurance_side_results: Array = insurance_result.get("blackjack_side_bet_results", []) as Array
	if insurance_side_results.is_empty() or int((insurance_side_results[0] as Dictionary).get("stake", 0)) != 5:
		failures.append("Blackjack insurance was not priced at half the main wager.")
	var selected_count_state := forced_count_state.duplicate(true)
	selected_count_state["selected_action_id"] = "count_cards"
	selected_count_state["selected_action_kind"] = "cheat"
	var repeat_count := game.surface_action_command("blackjack_count_toggle", 0, false, selected_count_state, split_run_state, split_environment)
	var repeated_challenge: Dictionary = (repeat_count.get("ui_state", {}) as Dictionary).get("count_challenge", {})
	if str(repeat_count.get("action_id", "")) == "count_cards" or bool(repeat_count.get("resolve", false)):
		failures.append("Blackjack count resolved an already-selected active challenge instead of keeping the live overlay running.")
	if not repeated_challenge.is_empty():
		failures.append("Blackjack count toggle did not disarm an active persistent count.")
	var persistent_count_run_state: RunState = RunStateScript.new()
	persistent_count_run_state.start_new("BLACKJACK-PERSISTENT-COUNT")
	var persistent_count_environment := _surface_contract_environment()
	var persistent_count_table := generated_state.duplicate(true)
	persistent_count_table["shoe_cursor"] = 0
	persistent_count_table["patrons"] = [
		{"id": "persist_patron_0", "name": "Nix", "seat": 0, "temper": "careless", "watching": true, "snitch_risk": 10},
		{"id": "persist_patron_1", "name": "Vale", "seat": 1, "temper": "careful", "watching": true, "snitch_risk": 12},
	]
	persistent_count_table["side_bets"] = []
	persistent_count_table["rules"] = {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}
	persistent_count_table["shoe"] = [
		{"rank": 10, "suit": 0}, {"rank": 7, "suit": 2}, {"rank": 6, "suit": 1}, {"rank": 9, "suit": 3},
		{"rank": 4, "suit": 0}, {"rank": 8, "suit": 1}, {"rank": 3, "suit": 2}, {"rank": 2, "suit": 3},
		{"rank": 5, "suit": 0}, {"rank": 10, "suit": 1}, {"rank": 6, "suit": 2}, {"rank": 7, "suit": 3},
		{"rank": 8, "suit": 0}, {"rank": 9, "suit": 1}, {"rank": 10, "suit": 2}, {"rank": 11, "suit": 3}
	]
	persistent_count_environment["game_states"] = {"blackjack": persistent_count_table}
	var arm_count := game.surface_action_command("blackjack_count_toggle", 0, false, {"selected_stake": 5}, persistent_count_run_state, persistent_count_environment)
	var first_count_deal := game.surface_action_command("blackjack_deal", 0, false, arm_count.get("ui_state", {}), persistent_count_run_state, persistent_count_environment)
	if ((first_count_deal.get("ui_state", {}) as Dictionary).get("count_challenge", {}) as Dictionary).is_empty():
		failures.append("Blackjack persistent count did not auto-start on the first armed hand.")
	var first_count_stand := game.surface_action_command("blackjack_stand", 0, true, first_count_deal.get("ui_state", {}), persistent_count_run_state, persistent_count_environment)
	var first_count_stand_state: Dictionary = first_count_stand.get("ui_state", {})
	if bool(first_count_stand.get("resolve", false)) or not bool(first_count_stand_state.get("settlement_count_revealed", false)):
		failures.append("Blackjack active counting did not pause settlement to reveal real table cards for counting.")
	var settlement_challenge: Dictionary = first_count_stand_state.get("count_challenge", {})
	var settlement_cards: Array = settlement_challenge.get("cards", []) as Array
	var settlement_icons: Array = settlement_challenge.get("icons", []) as Array
	var settlement_countable_cards := 0
	for settlement_card_count_value in settlement_cards:
		if typeof(settlement_card_count_value) == TYPE_DICTIONARY and _blackjack_test_count_delta([settlement_card_count_value]) != 0:
			settlement_countable_cards += 1
	if settlement_icons.size() != settlement_countable_cards:
		failures.append("Blackjack settlement count preview created pulses for neutral cards or missed countable cards.")
	for settlement_icon_value in settlement_icons:
		if typeof(settlement_icon_value) == TYPE_DICTIONARY and int((settlement_icon_value as Dictionary).get("count_value", 0)) == 0:
			failures.append("Blackjack settlement count preview created a zero-value pulse.")
	var settlement_has_hole_card := false
	for settlement_card_value in settlement_cards:
		if typeof(settlement_card_value) == TYPE_DICTIONARY and str((settlement_card_value as Dictionary).get("_count_source_key", "")).begins_with("dealer:1:"):
			settlement_has_hole_card = true
	if not settlement_has_hole_card:
		failures.append("Blackjack settlement count preview did not include the revealed dealer hole card.")
	var first_count_result := game.resolve_with_context("play_basic", 5, persistent_count_run_state, persistent_count_environment, persistent_count_run_state.create_rng("blackjack_persistent_count_resolve"), first_count_stand.get("ui_state", {}))
	if not bool(((persistent_count_environment.get("game_states", {}) as Dictionary).get("blackjack", {}) as Dictionary).get("counting_enabled", false)):
		failures.append("Blackjack count toggle did not remain enabled after hand settlement.")
	var second_count_deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, persistent_count_run_state, persistent_count_environment)
	if ((second_count_deal.get("ui_state", {}) as Dictionary).get("count_challenge", {}) as Dictionary).is_empty():
		failures.append("Blackjack persistent count did not auto-start on the next hand.")
	if (first_count_result.get("blackjack_patron_hands", []) as Array).is_empty():
		failures.append("Blackjack settlement did not expose patron hands in the result payload.")
	var multi_count_run_state: RunState = RunStateScript.new()
	multi_count_run_state.start_new("BLACKJACK-MULTI-HAND-COUNT")
	var multi_count_environment := _surface_contract_environment()
	var multi_count_table := generated_state.duplicate(true)
	multi_count_table["deck_count"] = 1
	multi_count_table["shoe_cursor"] = 0
	multi_count_table["patrons"] = []
	multi_count_table["side_bets"] = []
	multi_count_table["cut_card_remaining"] = 1
	multi_count_table["running_count"] = 0
	multi_count_table["recorded_running_count"] = 0
	multi_count_table["rules"] = {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}
	multi_count_table["shoe"] = [
		{"rank": 10, "suit": 0}, {"rank": 2, "suit": 1}, {"rank": 6, "suit": 2}, {"rank": 7, "suit": 3}, {"rank": 5, "suit": 0}, {"rank": 10, "suit": 1},
		{"rank": 3, "suit": 0}, {"rank": 4, "suit": 1}, {"rank": 2, "suit": 2}, {"rank": 5, "suit": 3}, {"rank": 10, "suit": 2},
		{"rank": 9, "suit": 0}, {"rank": 8, "suit": 1}, {"rank": 7, "suit": 2}, {"rank": 6, "suit": 3}, {"rank": 5, "suit": 1}, {"rank": 4, "suit": 2}
	]
	multi_count_environment["game_states"] = {"blackjack": multi_count_table}
	var multi_arm_count := game.surface_action_command("blackjack_count_toggle", 0, false, {"selected_stake": 5}, multi_count_run_state, multi_count_environment)
	var multi_first_deal := game.surface_action_command("blackjack_deal", 0, false, multi_arm_count.get("ui_state", {}), multi_count_run_state, multi_count_environment)
	var multi_first_preview := game.surface_action_command("blackjack_stand", 0, true, multi_first_deal.get("ui_state", {}), multi_count_run_state, multi_count_environment)
	var multi_first_ui := _blackjack_click_all_count_icons(game, multi_first_preview.get("ui_state", {}), multi_count_run_state, multi_count_environment)
	var multi_first_count_action := game.resolve_with_context("count_cards", 0, multi_count_run_state, multi_count_environment, multi_count_run_state.create_rng("blackjack_multi_count_action"), multi_first_ui)
	var multi_first_count_action_ui: Dictionary = multi_first_count_action.get("blackjack_surface_ui_state", {}) if typeof(multi_first_count_action.get("blackjack_surface_ui_state", {})) == TYPE_DICTIONARY else {}
	if not bool(multi_first_count_action.get("preserve_surface_ui_state", false)) or multi_first_count_action_ui.is_empty():
		failures.append("Blackjack standalone count action did not return preserved hand UI state.")
	if not bool(multi_first_count_action_ui.get("count_answered", false)) or int(multi_first_count_action_ui.get("count_delta", 999)) != int(multi_first_ui.get("count_delta", 0)):
		failures.append("Blackjack standalone count action did not preserve the finalized live count delta.")
	var multi_first_result := game.resolve_with_context("play_basic", 5, multi_count_run_state, multi_count_environment, multi_count_run_state.create_rng("blackjack_multi_count_first"), multi_first_count_action_ui)
	var multi_first_expected_count := _blackjack_test_result_count_delta(multi_first_result)
	var multi_after_first: Dictionary = (multi_count_environment.get("game_states", {}) as Dictionary).get("blackjack", {})
	if int(multi_after_first.get("recorded_running_count", 999)) != multi_first_expected_count:
		failures.append("Blackjack recorded count did not persist after the first counted hand.")
	var multi_second_deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, multi_count_run_state, multi_count_environment)
	var multi_second_surface := game.surface_state(multi_count_run_state, multi_count_environment, multi_second_deal.get("ui_state", {}))
	if int(multi_second_surface.get("persisted_recorded_running_count", 999)) != multi_first_expected_count or int(multi_second_surface.get("recorded_running_count", 999)) != multi_first_expected_count:
		failures.append("Blackjack recorded count was not visible at the start of the next hand.")
	var multi_second_preview := game.surface_action_command("blackjack_stand", 0, true, multi_second_deal.get("ui_state", {}), multi_count_run_state, multi_count_environment)
	var multi_second_ui := _blackjack_click_all_count_icons(game, multi_second_preview.get("ui_state", {}), multi_count_run_state, multi_count_environment)
	var multi_second_result := game.resolve_with_context("play_basic", 5, multi_count_run_state, multi_count_environment, multi_count_run_state.create_rng("blackjack_multi_count_second"), multi_second_ui)
	var multi_second_challenge: Dictionary = multi_second_ui.get("count_challenge", {}) if typeof(multi_second_ui.get("count_challenge", {})) == TYPE_DICTIONARY else {}
	var multi_second_expected_count := multi_first_expected_count + _blackjack_test_result_count_delta(multi_second_result)
	var multi_after_second: Dictionary = (multi_count_environment.get("game_states", {}) as Dictionary).get("blackjack", {})
	if int(multi_after_second.get("recorded_running_count", 999)) != multi_second_expected_count:
		failures.append("Blackjack recorded count did not accumulate across multiple hands in the same shoe: expected %+d, got %+d; first %+d, second result %+d, second challenge %+d." % [multi_second_expected_count, int(multi_after_second.get("recorded_running_count", 999)), multi_first_expected_count, _blackjack_test_result_count_delta(multi_second_result), int(multi_second_challenge.get("target_delta", 999))])
	if int(multi_second_result.get("blackjack_recorded_count", 999)) != multi_second_expected_count:
		failures.append("Blackjack result payload did not report the accumulated recorded count: expected %+d, got %+d; first %+d, second result %+d, second challenge %+d." % [multi_second_expected_count, int(multi_second_result.get("blackjack_recorded_count", 999)), multi_first_expected_count, _blackjack_test_result_count_delta(multi_second_result), int(multi_second_challenge.get("target_delta", 999))])
	var low_bankroll: RunState = RunStateScript.new()
	low_bankroll.start_new("BLACKJACK-LOW-BANKROLL")
	low_bankroll.change_bankroll(-95)
	var low_deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, low_bankroll, split_environment)
	var low_surface := game.surface_state(low_bankroll, split_environment, low_deal.get("ui_state", {}))
	if bool(low_surface.get("can_split", false)) or bool(low_surface.get("can_double", false)):
		failures.append("Blackjack offered split or double when the projected wager exceeded bankroll.")
	var side_click := game.surface_action_command("blackjack_side_bet", 0, false, {}, split_run_state, split_environment)
	var split_deal := game.surface_action_command("blackjack_deal", 0, false, side_click.get("ui_state", {}), split_run_state, split_environment)
	var split_ui: Dictionary = split_deal.get("ui_state", {})
	if (split_ui.get("blackjack_side_bets", []) as Array).is_empty():
		failures.append("Blackjack side-bet toggle did not persist in UI-local state.")
	var split_click := game.surface_action_command("blackjack_split", 0, false, split_ui, split_run_state, split_environment)
	split_ui = split_click.get("ui_state", {})
	if (split_ui.get("player_hands", []) as Array).size() != 2:
		failures.append("Blackjack split did not create two hands.")
	var double_click := game.surface_action_command("blackjack_double", 0, false, split_ui, split_run_state, split_environment)
	split_ui = double_click.get("ui_state", {})
	if (split_ui.get("player_hands", []) as Array).size() != 2:
		failures.append("Blackjack double after split lost split hand state.")
	var settle_command := {}
	for _i in range(4):
		settle_command = game.surface_action_command("blackjack_stand", 0, true, split_ui, split_run_state, split_environment)
		split_ui = settle_command.get("ui_state", {})
		if bool(settle_command.get("resolve", false)):
			break
	if not bool(settle_command.get("resolve", false)):
		failures.append("Blackjack split hands did not reach a resolvable state after standing.")
	var split_before := _run_state_result_snapshot(split_run_state)
	var split_result := game.resolve_with_context("play_basic", 5, split_run_state, split_environment, split_run_state.create_rng("blackjack_split_resolve"), split_ui)
	_check_action_result_shape(split_result, "legal", failures)
	_check_action_result_applied(split_before, split_run_state, split_result, "blackjack split hand result", failures)
	if (split_result.get("blackjack_hand_results", []) as Array).size() != 2:
		failures.append("Blackjack split result did not settle both hands.")
	var split_side_results: Array = split_result.get("blackjack_side_bet_results", []) as Array
	if split_side_results.is_empty():
		failures.append("Blackjack result did not settle selected side bets.")
	else:
		var pair_result: Dictionary = split_side_results[0]
		if str(pair_result.get("id", "")) != "perfect_pairs" or not bool(pair_result.get("won", false)) or str(pair_result.get("detail", "")) != "mixed pair":
			failures.append("Blackjack perfect-pairs side bet did not settle from the initial deal.")
	var updated_table: Dictionary = (split_environment.get("game_states", {}) as Dictionary).get("blackjack", {})
	if int(updated_table.get("hands_played", 0)) <= 0:
		failures.append("Blackjack resolve did not update persistent table hand count.")
	var last_result: Dictionary = updated_table.get("last_result", {}) if typeof(updated_table.get("last_result", {})) == TYPE_DICTIONARY else {}
	if not last_result.has("headline") or not last_result.has("bankroll_delta") or not last_result.has("hand_results"):
		failures.append("Blackjack resolve did not persist an in-table result payload.")
	if (last_result.get("side_bet_results", []) as Array).is_empty():
		failures.append("Blackjack persisted result did not include placed side-bet outcome details.")

	var shoe_persist_run_state: RunState = RunStateScript.new()
	shoe_persist_run_state.start_new("BLACKJACK-SHOE-PERSISTENCE")
	var shoe_persist_environment := _surface_contract_environment()
	var shoe_persist_table := generated_state.duplicate(true)
	shoe_persist_table["shoe_cursor"] = 0
	shoe_persist_table["patrons"] = []
	shoe_persist_table["side_bets"] = []
	shoe_persist_table["cut_card_remaining"] = 1
	var shoe_persist_start_size := (shoe_persist_table.get("shoe", []) as Array).size()
	shoe_persist_environment["game_states"] = {"blackjack": shoe_persist_table}
	var shoe_persist_deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, shoe_persist_run_state, shoe_persist_environment)
	var shoe_persist_stand := game.surface_action_command("blackjack_stand", 0, true, shoe_persist_deal.get("ui_state", {}), shoe_persist_run_state, shoe_persist_environment)
	var shoe_persist_result := game.resolve_with_context("play_basic", 5, shoe_persist_run_state, shoe_persist_environment, shoe_persist_run_state.create_rng("blackjack_shoe_persist_resolve"), shoe_persist_stand.get("ui_state", {}))
	var _shoe_persist_delta := int(shoe_persist_result.get("blackjack_main_delta", 0))
	var shoe_persist_updated: Dictionary = (shoe_persist_environment.get("game_states", {}) as Dictionary).get("blackjack", {})
	var persisted_shoe: Array = shoe_persist_updated.get("shoe", []) as Array
	var persisted_composition: Dictionary = shoe_persist_updated.get("shoe_composition", {}) if typeof(shoe_persist_updated.get("shoe_composition", {})) == TYPE_DICTIONARY else {}
	if persisted_shoe.is_empty() or persisted_shoe.size() >= shoe_persist_start_size:
		failures.append("Blackjack resolve did not persist the actual shorter remaining shoe.")
	if int(shoe_persist_updated.get("shoe_remaining", -1)) != persisted_shoe.size() or int(persisted_composition.get("total", -1)) != persisted_shoe.size():
		failures.append("Blackjack persistent shoe metadata did not match the actual remaining cards.")
	if int(shoe_persist_updated.get("shoe_cursor", -1)) != 0:
		failures.append("Blackjack persistent shoe still used a cursor instead of the remaining card array.")

	var shuffle_run_state: RunState = RunStateScript.new()
	shuffle_run_state.start_new("BLACKJACK-SHOE-SHUFFLE")
	var shuffle_environment := _surface_contract_environment()
	var shuffle_table := generated_state.duplicate(true)
	shuffle_table["deck_count"] = 1
	shuffle_table["shoe_cursor"] = 0
	shuffle_table["patrons"] = []
	shuffle_table["side_bets"] = []
	shuffle_table["cut_card_remaining"] = 10
	shuffle_table["running_count"] = 5
	shuffle_table["recorded_running_count"] = 3
	shuffle_table["shoe"] = [
		{"rank": 10, "suit": 0}, {"rank": 9, "suit": 2}, {"rank": 6, "suit": 1}, {"rank": 7, "suit": 3},
		{"rank": 10, "suit": 2}, {"rank": 5, "suit": 1}, {"rank": 4, "suit": 0}, {"rank": 3, "suit": 2}
	]
	shuffle_environment["game_states"] = {"blackjack": shuffle_table}
	var shuffle_deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, shuffle_run_state, shuffle_environment)
	var shuffle_stand := game.surface_action_command("blackjack_stand", 0, true, shuffle_deal.get("ui_state", {}), shuffle_run_state, shuffle_environment)
	var _shuffle_result := game.resolve_with_context("play_basic", 5, shuffle_run_state, shuffle_environment, shuffle_run_state.create_rng("blackjack_forced_shuffle_resolve"), shuffle_stand.get("ui_state", {}))
	var shuffle_updated: Dictionary = (shuffle_environment.get("game_states", {}) as Dictionary).get("blackjack", {})
	var shuffled_shoe: Array = shuffle_updated.get("shoe", []) as Array
	var shuffle_composition: Dictionary = shuffle_updated.get("shoe_composition", {}) if typeof(shuffle_updated.get("shoe_composition", {})) == TYPE_DICTIONARY else {}
	if shuffled_shoe.size() != 52 or int(shuffle_composition.get("total", -1)) != 52:
		failures.append("Blackjack cut-card shuffle did not rebuild a full shoe from the declared deck count.")
	if int(shuffle_updated.get("running_count", 99)) != 0 or int(shuffle_updated.get("recorded_running_count", 99)) != 0:
		failures.append("Blackjack cut-card shuffle did not reset true and recorded counts.")
	if int(shuffle_updated.get("last_shuffle_hand", 0)) <= 0:
		failures.append("Blackjack cut-card shuffle did not record the shuffle hand.")

	var ladies_run_state: RunState = RunStateScript.new()
	ladies_run_state.start_new("BLACKJACK-LUCKY-LADIES")
	ladies_run_state.add_item("lucky_ladies_compact")
	var ladies_environment := _surface_contract_environment()
	var ladies_table := generated_state.duplicate(true)
	ladies_table["shoe_cursor"] = 0
	ladies_table["patrons"] = []
	ladies_table["side_bets"] = [{"id": "lucky_ladies", "label": "Lucky Ladies", "summary": "First two total 20"}]
	ladies_table["rules"] = {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4}
	ladies_table["shoe"] = [
		{"rank": 12, "suit": 1}, {"rank": 14, "suit": 0}, {"rank": 12, "suit": 0}, {"rank": 13, "suit": 2},
		{"rank": 9, "suit": 0}, {"rank": 8, "suit": 1}, {"rank": 7, "suit": 2}, {"rank": 6, "suit": 3}
	]
	ladies_environment["game_states"] = {"blackjack": ladies_table}
	var ladies_side_click := game.surface_action_command("blackjack_side_bet", 0, false, {"selected_stake": 5}, ladies_run_state, ladies_environment)
	var ladies_side_surface := game.surface_state(ladies_run_state, ladies_environment, ladies_side_click.get("ui_state", {}))
	var ladies_side_stakes: Dictionary = ladies_side_surface.get("side_bet_stakes", {}) if typeof(ladies_side_surface.get("side_bet_stakes", {})) == TYPE_DICTIONARY else {}
	if int(ladies_side_stakes.get("lucky_ladies", 0)) != 4:
		failures.append("Lucky Ladies Compact did not double the Lucky Ladies side-bet stake.")
	var ladies_compact_visible := false
	var ladies_available_side_bets: Array = ladies_side_surface.get("side_bets_available", []) as Array
	for side_bet_value in ladies_available_side_bets:
		if typeof(side_bet_value) == TYPE_DICTIONARY and str((side_bet_value as Dictionary).get("id", "")) == "lucky_ladies":
			ladies_compact_visible = bool((side_bet_value as Dictionary).get("item_boosted", false))
			break
	if not ladies_compact_visible:
		failures.append("Lucky Ladies Compact did not mark the side bet as item-boosted in the surface state.")
	var ladies_deal := game.surface_action_command("blackjack_deal", 0, false, ladies_side_click.get("ui_state", {}), ladies_run_state, ladies_environment)
	var ladies_ui: Dictionary = ladies_deal.get("ui_state", {})
	var ladies_settle := game.surface_action_command("blackjack_stand", 0, true, ladies_ui, ladies_run_state, ladies_environment)
	ladies_ui = ladies_settle.get("ui_state", {})
	var ladies_result := game.resolve_with_context("play_basic", 5, ladies_run_state, ladies_environment, ladies_run_state.create_rng("blackjack_lucky_ladies_resolve"), ladies_ui)
	var ladies_side_results: Array = ladies_result.get("blackjack_side_bet_results", []) as Array
	if ladies_side_results.is_empty():
		failures.append("Blackjack Lucky Ladies side bet did not settle.")
	else:
		var ladies_side_result: Dictionary = ladies_side_results[0]
		if int(ladies_side_result.get("stake", 0)) != 4 or int(ladies_side_result.get("payout_mult", 0)) != 8:
			failures.append("Lucky Ladies Compact did not double the winning Lucky Ladies payout odds.")
		if int(ladies_side_result.get("payout_mult", 0)) == 200 or str(ladies_side_result.get("detail", "")) == "queen hearts with dealer blackjack":
			failures.append("Blackjack Lucky Ladies awarded the queen-hearts jackpot with only one queen of hearts.")
	var cheat_before := _run_state_result_snapshot(split_run_state)
	var cheat_result := game.resolve_with_context("peek_hole_card", 0, split_run_state, split_environment, split_run_state.create_rng("blackjack_peek_resolve"), peek_click.get("ui_state", {}))
	_check_action_result_shape(cheat_result, "cheat", failures)
	_check_action_result_applied(cheat_before, split_run_state, cheat_result, "blackjack peek cheat result", failures)
	split_run_state.set_environment(split_environment)
	_check_blackjack_rule_matrix(game, generated_state, failures)
	var restored: RunState = RunStateScript.new()
	restored.from_dict(split_run_state.to_dict())
	var restored_game_states: Dictionary = restored.current_environment.get("game_states", {})
	if not restored_game_states.has("blackjack"):
		failures.append("Blackjack generated table state did not round-trip through RunState serialization.")


func _check_blackjack_surface_time_resolve_determinism(game: GameModule, table_state: Dictionary, failures: Array) -> void:
	var run_a: RunState = RunStateScript.new()
	var run_b: RunState = RunStateScript.new()
	run_a.start_new("BLACKJACK-SURFACE-TIME-DETERMINISM")
	run_b.start_new("BLACKJACK-SURFACE-TIME-DETERMINISM")
	run_a.bankroll = 200
	run_b.bankroll = 200
	var environment_a := _surface_contract_environment()
	var environment_b := _surface_contract_environment()
	environment_a["game_states"] = {"blackjack": table_state.duplicate(true)}
	environment_b["game_states"] = {"blackjack": table_state.duplicate(true)}
	run_a.current_environment = environment_a.duplicate(true)
	run_b.current_environment = environment_b.duplicate(true)
	var ui_state := {
		"selected_stake": 5,
		"surface_time_msec": 24000,
	}
	var result_a: Dictionary = game.resolve_with_context("peek_hole_card", 5, run_a, environment_a, run_a.create_rng(), ui_state.duplicate(true))
	var result_b: Dictionary = game.resolve_with_context("peek_hole_card", 5, run_b, environment_b, run_b.create_rng(), ui_state.duplicate(true))
	for key in ["ok", "action_id", "action_kind", "bankroll_delta", "suspicion_delta", "base_suspicion_delta", "blackjack_table_barred", "blackjack_watched_peek", "blackjack_confiscated_bet", "message"]:
		if result_a.get(key, null) != result_b.get(key, null):
			failures.append("Blackjack supplied surface_time_msec resolve was not deterministic for %s." % str(key))
			break
	if run_a.bankroll != run_b.bankroll or run_a.suspicion_level() != run_b.suspicion_level():
		failures.append("Blackjack supplied surface_time_msec resolve left divergent RunState economy/heat.")


func _check_blackjack_rule_matrix(game: GameModule, base_table: Dictionary, failures: Array) -> void:
	_check_blackjack_soft_17_matrix(game, base_table, failures)
	_check_blackjack_split_policy_matrix(game, base_table, failures)
	_check_blackjack_insurance_matrix(game, base_table, failures)
	_check_blackjack_payout_message_matrix(game, base_table, failures)


func _blackjack_rule_table(base_table: Dictionary, rules: Dictionary, shoe: Array, side_bets: Array = []) -> Dictionary:
	var table := base_table.duplicate(true)
	table["shoe_cursor"] = 0
	table["patrons"] = []
	table["side_bets"] = side_bets.duplicate(true)
	table["rules"] = rules.duplicate(true)
	table["shoe"] = shoe.duplicate(true)
	table["shoe_remaining"] = shoe.size()
	table["shoe_composition"] = {}
	table["last_result"] = {}
	return table


func _blackjack_rule_fixture(game: GameModule, seed: String, table: Dictionary, stake: int = 10) -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed)
	run_state.bankroll = 1000
	var environment := _surface_contract_environment()
	environment["game_states"] = {"blackjack": table}
	var deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": stake}, run_state, environment)
	return {
		"run_state": run_state,
		"environment": environment,
		"ui": deal.get("ui_state", {}),
	}


func _blackjack_stand_and_resolve(game: GameModule, fixture: Dictionary, stake: int, rng_key: String) -> Dictionary:
	var run_state: RunState = fixture.get("run_state", null)
	var environment: Dictionary = fixture.get("environment", {})
	var ui: Dictionary = fixture.get("ui", {})
	var stand := game.surface_action_command("blackjack_stand", 0, true, ui, run_state, environment)
	ui = stand.get("ui_state", {})
	return game.resolve_with_context("play_basic", stake, run_state, environment, run_state.create_rng(rng_key), ui)


func _check_blackjack_soft_17_matrix(game: GameModule, base_table: Dictionary, failures: Array) -> void:
	var shoe := [
		{"rank": 10, "suit": 0}, {"rank": 14, "suit": 1}, {"rank": 7, "suit": 2}, {"rank": 6, "suit": 3},
		{"rank": 2, "suit": 0}, {"rank": 9, "suit": 1}, {"rank": 4, "suit": 2}, {"rank": 3, "suit": 3}
	]
	var s17_table := _blackjack_rule_table(base_table, {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}, shoe)
	var s17_result := _blackjack_stand_and_resolve(game, _blackjack_rule_fixture(game, "BLACKJACK-RULE-S17", s17_table), 10, "blackjack_rule_s17")
	if (s17_result.get("blackjack_dealer", []) as Array).size() != 2:
		failures.append("Blackjack S17 table drew on dealer soft 17.")
	var h17_table := _blackjack_rule_table(base_table, {"dealer_hits_soft_17": true, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}, shoe)
	var h17_result := _blackjack_stand_and_resolve(game, _blackjack_rule_fixture(game, "BLACKJACK-RULE-H17", h17_table), 10, "blackjack_rule_h17")
	if (h17_result.get("blackjack_dealer", []) as Array).size() < 3:
		failures.append("Blackjack H17 table did not draw on dealer soft 17.")


func _check_blackjack_split_policy_matrix(game: GameModule, base_table: Dictionary, failures: Array) -> void:
	var live_split_ace_table := _blackjack_rule_table(base_table, {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}, [
		{"rank": 14, "suit": 0}, {"rank": 5, "suit": 1}, {"rank": 14, "suit": 2}, {"rank": 6, "suit": 3},
		{"rank": 14, "suit": 1}, {"rank": 6, "suit": 2}, {"rank": 9, "suit": 1}, {"rank": 8, "suit": 3}
	])
	var live_split_ace_fixture := _blackjack_rule_fixture(game, "BLACKJACK-RULE-SPLIT-ACES-LIVE", live_split_ace_table, 5)
	var live_split_ace_run_state: RunState = live_split_ace_fixture.get("run_state", null)
	var live_split_ace_environment: Dictionary = live_split_ace_fixture.get("environment", {})
	var live_split_ace_ui: Dictionary = live_split_ace_fixture.get("ui", {})
	var live_split_ace := game.surface_action_command("blackjack_split", 0, false, live_split_ace_ui, live_split_ace_run_state, live_split_ace_environment)
	live_split_ace_ui = live_split_ace.get("ui_state", {})
	var live_split_ace_hands: Array = live_split_ace_ui.get("player_hands", []) as Array
	if live_split_ace_hands.size() != 2:
		failures.append("Blackjack split aces did not create two live hands.")
	else:
		var live_first_hand: Dictionary = live_split_ace_hands[0]
		var live_second_hand: Dictionary = live_split_ace_hands[1]
		if bool(live_first_hand.get("stood", false)) or bool(live_second_hand.get("stood", false)):
			failures.append("Blackjack auto-stood split aces below 21.")
	var live_split_ace_surface := game.surface_state(live_split_ace_run_state, live_split_ace_environment, live_split_ace_ui)
	if int(live_split_ace_surface.get("active_hand_index", -1)) != 0 or int(live_split_ace_surface.get("blackjack_total", 0)) != 12 or not bool(live_split_ace_surface.get("can_hit", false)) or not bool(live_split_ace_surface.get("can_stand", false)):
		failures.append("Blackjack split ace 12 was not left as a playable active hand.")
	var live_split_ace_stand := game.surface_action_command("blackjack_stand", 0, false, live_split_ace_ui, live_split_ace_run_state, live_split_ace_environment)
	var live_second_ace_ui: Dictionary = live_split_ace_stand.get("ui_state", {})
	var live_second_ace_surface := game.surface_state(live_split_ace_run_state, live_split_ace_environment, live_second_ace_ui)
	if int(live_second_ace_surface.get("active_hand_index", -1)) != 1 or int(live_second_ace_surface.get("blackjack_total", 0)) != 17 or not bool(live_second_ace_surface.get("can_hit", false)) or not bool(live_second_ace_surface.get("can_stand", false)):
		failures.append("Blackjack split ace 17 was not left as a playable active hand.")

	var split_ace_21_table := _blackjack_rule_table(base_table, {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}, [
		{"rank": 14, "suit": 0}, {"rank": 5, "suit": 1}, {"rank": 14, "suit": 2}, {"rank": 6, "suit": 3},
		{"rank": 13, "suit": 0}, {"rank": 6, "suit": 1}, {"rank": 7, "suit": 2}, {"rank": 8, "suit": 3}
	])
	var split_ace_21_fixture := _blackjack_rule_fixture(game, "BLACKJACK-RULE-SPLIT-ACES-21", split_ace_21_table, 5)
	var split_ace_21_run_state: RunState = split_ace_21_fixture.get("run_state", null)
	var split_ace_21_environment: Dictionary = split_ace_21_fixture.get("environment", {})
	var split_ace_21_ui: Dictionary = split_ace_21_fixture.get("ui", {})
	var split_ace_21 := game.surface_action_command("blackjack_split", 0, false, split_ace_21_ui, split_ace_21_run_state, split_ace_21_environment)
	split_ace_21_ui = split_ace_21.get("ui_state", {})
	var split_ace_21_hands: Array = split_ace_21_ui.get("player_hands", []) as Array
	if split_ace_21_hands.size() != 2:
		failures.append("Blackjack split ace 21 fixture did not create two hands.")
	else:
		var split_ace_21_first: Dictionary = split_ace_21_hands[0]
		var split_ace_21_second: Dictionary = split_ace_21_hands[1]
		if not bool(split_ace_21_first.get("stood", false)) or str(split_ace_21_first.get("terminal_reason", "")) != "21":
			failures.append("Blackjack split ace 21 did not auto-complete as the only automatic stand.")
		if bool(split_ace_21_second.get("stood", false)):
			failures.append("Blackjack auto-stood a split ace 17 while advancing past a split ace 21.")
	var split_ace_21_surface := game.surface_state(split_ace_21_run_state, split_ace_21_environment, split_ace_21_ui)
	if int(split_ace_21_surface.get("active_hand_index", -1)) != 1 or int(split_ace_21_surface.get("blackjack_total", 0)) != 17 or not bool(split_ace_21_surface.get("can_hit", false)) or not bool(split_ace_21_surface.get("can_stand", false)):
		failures.append("Blackjack split ace 21 did not advance to the next playable split hand.")
	var split_ace_result := game.resolve_with_context("play_basic", 5, split_ace_21_run_state, split_ace_21_environment, split_ace_21_run_state.create_rng("blackjack_rule_split_aces"), split_ace_21_ui)
	for hand_value in split_ace_result.get("blackjack_hand_results", []) as Array:
		if typeof(hand_value) == TYPE_DICTIONARY and bool((hand_value as Dictionary).get("blackjack", false)):
			failures.append("Blackjack treated a split-ace 21 as a natural blackjack.")

	var resplit_table := _blackjack_rule_table(base_table, {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}, [
		{"rank": 8, "suit": 0}, {"rank": 5, "suit": 1}, {"rank": 8, "suit": 2}, {"rank": 6, "suit": 3},
		{"rank": 8, "suit": 1}, {"rank": 3, "suit": 0}, {"rank": 10, "suit": 2}, {"rank": 2, "suit": 3}
	])
	var resplit_fixture := _blackjack_rule_fixture(game, "BLACKJACK-RULE-RESPLIT", resplit_table, 5)
	var resplit_ui: Dictionary = resplit_fixture.get("ui", {})
	var first_split := game.surface_action_command("blackjack_split", 0, false, resplit_ui, resplit_fixture.get("run_state", null), resplit_fixture.get("environment", {}))
	resplit_ui = first_split.get("ui_state", {})
	var resplit_surface := game.surface_state(resplit_fixture.get("run_state", null), resplit_fixture.get("environment", {}), resplit_ui)
	if not bool(resplit_surface.get("can_split", false)):
		failures.append("Blackjack did not allow re-splitting a non-ace pair before max hands.")
	var second_split := game.surface_action_command("blackjack_split", 0, false, resplit_ui, resplit_fixture.get("run_state", null), resplit_fixture.get("environment", {}))
	var second_split_ui: Dictionary = second_split.get("ui_state", {})
	var second_split_hands: Array = second_split_ui.get("player_hands", []) as Array
	if second_split_hands.size() != 3:
		failures.append("Blackjack re-split did not create a third hand.")

	var capped_table := _blackjack_rule_table(base_table, {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 2, "late_surrender": true}, [
		{"rank": 8, "suit": 0}, {"rank": 5, "suit": 1}, {"rank": 8, "suit": 2}, {"rank": 6, "suit": 3},
		{"rank": 8, "suit": 1}, {"rank": 3, "suit": 0}, {"rank": 10, "suit": 2}, {"rank": 2, "suit": 3}
	])
	var capped_fixture := _blackjack_rule_fixture(game, "BLACKJACK-RULE-SPLIT-CAP", capped_table, 5)
	var capped_split := game.surface_action_command("blackjack_split", 0, false, capped_fixture.get("ui", {}), capped_fixture.get("run_state", null), capped_fixture.get("environment", {}))
	var capped_surface := game.surface_state(capped_fixture.get("run_state", null), capped_fixture.get("environment", {}), capped_split.get("ui_state", {}))
	if bool(capped_surface.get("can_split", false)):
		failures.append("Blackjack allowed re-splitting after reaching the max split hand count.")

	var no_das_table := _blackjack_rule_table(base_table, {"dealer_hits_soft_17": false, "double_after_split": false, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}, [
		{"rank": 8, "suit": 0}, {"rank": 5, "suit": 1}, {"rank": 8, "suit": 2}, {"rank": 6, "suit": 3},
		{"rank": 3, "suit": 1}, {"rank": 4, "suit": 0}, {"rank": 10, "suit": 2}, {"rank": 2, "suit": 3}
	])
	var no_das_fixture := _blackjack_rule_fixture(game, "BLACKJACK-RULE-NODAS", no_das_table, 5)
	var no_das_split := game.surface_action_command("blackjack_split", 0, false, no_das_fixture.get("ui", {}), no_das_fixture.get("run_state", null), no_das_fixture.get("environment", {}))
	var no_das_surface := game.surface_state(no_das_fixture.get("run_state", null), no_das_fixture.get("environment", {}), no_das_split.get("ui_state", {}))
	if bool(no_das_surface.get("can_double", false)):
		failures.append("Blackjack allowed double after split on a no-DAS table.")

	var no_surrender_table := _blackjack_rule_table(base_table, {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": false}, [
		{"rank": 10, "suit": 0}, {"rank": 9, "suit": 1}, {"rank": 6, "suit": 2}, {"rank": 7, "suit": 3}
	])
	var no_surrender_fixture := _blackjack_rule_fixture(game, "BLACKJACK-RULE-NOSURRENDER", no_surrender_table, 5)
	var no_surrender_surface := game.surface_state(no_surrender_fixture.get("run_state", null), no_surrender_fixture.get("environment", {}), no_surrender_fixture.get("ui", {}))
	if bool(no_surrender_surface.get("can_surrender", false)):
		failures.append("Blackjack exposed surrender on a no-surrender table.")


func _check_blackjack_insurance_matrix(game: GameModule, base_table: Dictionary, failures: Array) -> void:
	var insurance_table := _blackjack_rule_table(base_table, {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}, [
		{"rank": 10, "suit": 0}, {"rank": 14, "suit": 1}, {"rank": 9, "suit": 2}, {"rank": 13, "suit": 3},
		{"rank": 7, "suit": 0}, {"rank": 6, "suit": 1}
	], [
		{"id": "perfect_pairs", "label": "Perfect Pairs", "summary": "Pair first two cards"},
		{"id": "lucky_ladies", "label": "Lucky Ladies", "summary": "First two total 20"},
	])
	var fixture := _blackjack_rule_fixture(game, "BLACKJACK-RULE-INSURANCE", insurance_table, 10)
	var surface := game.surface_state(fixture.get("run_state", null), fixture.get("environment", {}), fixture.get("ui", {}))
	var insurance_index := -1
	var offered: Array = surface.get("side_bets_available", []) as Array
	for i in range(offered.size()):
		if typeof(offered[i]) == TYPE_DICTIONARY and str((offered[i] as Dictionary).get("id", "")) == "insurance":
			insurance_index = i
			break
	if insurance_index < 0:
		failures.append("Blackjack did not offer insurance on an ace upcard when ordinary table side bets were full.")
		return
	var click := game.surface_action_command("blackjack_side_bet", insurance_index, false, fixture.get("ui", {}), fixture.get("run_state", null), fixture.get("environment", {}))
	var stand := game.surface_action_command("blackjack_stand", 0, false, click.get("ui_state", {}), fixture.get("run_state", null), fixture.get("environment", {}))
	var run_state: RunState = fixture.get("run_state", null)
	var result := game.resolve_with_context("play_basic", 10, run_state, fixture.get("environment", {}), run_state.create_rng("blackjack_rule_insurance"), stand.get("ui_state", {}))
	var side_results: Array = result.get("blackjack_side_bet_results", []) as Array
	if side_results.is_empty() or str((side_results[0] as Dictionary).get("id", "")) != "insurance":
		failures.append("Blackjack implicit insurance did not settle as the selected side bet.")
	elif int((side_results[0] as Dictionary).get("stake", 0)) != 5 or int((side_results[0] as Dictionary).get("payout_mult", 0)) != 2:
		failures.append("Blackjack insurance did not price at half stake and pay 2:1.")


func _check_blackjack_payout_message_matrix(game: GameModule, base_table: Dictionary, failures: Array) -> void:
	var natural_table := _blackjack_rule_table(base_table, {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}, [
		{"rank": 14, "suit": 0}, {"rank": 9, "suit": 1}, {"rank": 13, "suit": 2}, {"rank": 7, "suit": 3}
	])
	var natural_result := _blackjack_stand_and_resolve(game, _blackjack_rule_fixture(game, "BLACKJACK-RULE-PAYOUT-NATURAL", natural_table, 10), 10, "blackjack_rule_payout_natural")
	var natural_message := str(natural_result.get("message", ""))
	if int(natural_result.get("blackjack_main_delta", 0)) != 15 or natural_message.find("3:2") < 0 or natural_message.find("6:5") >= 0:
		failures.append("Blackjack natural payout message did not state the 3:2 policy cleanly.")

	var push_table := _blackjack_rule_table(base_table, {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}, [
		{"rank": 10, "suit": 0}, {"rank": 9, "suit": 1}, {"rank": 8, "suit": 2}, {"rank": 9, "suit": 3}
	])
	var push_result := _blackjack_stand_and_resolve(game, _blackjack_rule_fixture(game, "BLACKJACK-RULE-PAYOUT-PUSH", push_table, 10), 10, "blackjack_rule_payout_push")
	if int(push_result.get("blackjack_main_delta", 999)) != 0 or str(push_result.get("message", "")).to_lower().find("push") < 0:
		failures.append("Blackjack push did not settle at zero with an explicit push message.")


func _check_video_poker_surface_contract(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("VIDEO-POKER-SURFACE-CONTRACT")
	var environment := _surface_contract_environment()
	var surface := game.surface_state(run_state, environment, {})
	if str(surface.get("surface_renderer", "")) != "card_machine":
		failures.append("Video poker surface did not route to the card-machine renderer.")
	_check_idle_animation_liveness_contract(surface, "Video poker cabinet surface", failures)
	if not bool(surface.get("surface_controls_native", false)):
		failures.append("Video poker surface did not expose native surface controls.")
	if not bool(surface.get("surface_animates_idle", false)):
		failures.append("Video poker cabinet lights do not keep the idle surface alive.")
	if (surface.get("hand", []) as Array).size() != 5:
		failures.append("Video poker surface did not expose a five-card hand.")
	if str(surface.get("phase", "")) != "idle":
		failures.append("Video poker surface should start idle before DEAL (phase=%s)." % str(surface.get("phase", "")))
	var paytable_bets: Array = surface.get("paytable_bets", [])
	if int(surface.get("paytable_columns", 0)) != 5 or paytable_bets.size() != 5:
		failures.append("Video poker surface did not expose the full 1-5 coin paytable columns.")
	if int(surface.get("active_paytable_column", -1)) != int(surface.get("bet_level", -2)) or int(surface.get("highlight_bet_column", -1)) != int(surface.get("bet_level", -2)):
		failures.append("Video poker surface did not mark the current-bet paytable column.")
	if int(surface.get("coin_count", 0)) != 1:
		failures.append("Video poker fresh cabinet should begin at one coin per hand.")
	var idle_hand: Array = surface.get("hand", []) as Array
	var first_idle_card: Dictionary = idle_hand[0] if idle_hand.size() > 0 and typeof(idle_hand[0]) == TYPE_DICTIONARY else {}
	if not first_idle_card.has("hidden"):
		failures.append("Video poker idle surface should show card backs instead of an already-dealt hand.")
	var idle_harness := SurfaceHarness.new()
	idle_harness.setup(surface)
	game.draw_surface(idle_harness, surface, {"contract_harness": true})
	_check_surface_hit_layout(idle_harness, "Video poker idle surface", failures)
	var idle_paytable_visible := false
	for label_value in idle_harness.labels:
		if str(label_value).begins_with("PAY TABLE"):
			idle_paytable_visible = true
	if not idle_paytable_visible:
		failures.append("Video poker renderer did not keep the paytable visible while idle.")
	for action in ["video_poker_bet_down", "video_poker_bet_one", "video_poker_bet_max", "video_poker_denom", "video_poker_deal"]:
		if not _surface_harness_has_action(idle_harness, action):
			failures.append("Video poker idle cabinet is missing %s." % action)
	_check_video_poker_bet_controls(game, failures)
	var idle_draw := game.surface_action_command("video_poker_draw", 0, false, {}, run_state, environment)
	if str(idle_draw.get("action_id", "")) == "draw":
		failures.append("Video poker DRAW should not resolve before DEAL.")
	var idle_mark := game.surface_action_command("video_poker_mark", 0, false, {}, run_state, environment)
	if str(idle_mark.get("action_id", "")) == "mark_holds":
		failures.append("Video poker MARK HOLDS should not arm before DEAL.")
	var deal_click := _check_surface_command_non_mutating(game, "video_poker_deal", 0, false, {}, run_state, environment, "video poker deal", failures)
	var deal_state: Dictionary = deal_click.get("ui_state", {})
	if int(deal_state.get("deal_started_msec", 0)) <= 0:
		failures.append("Video poker DEAL emitted a zero surface-clock animation start, which can leave cards face down indefinitely.")
	var dealt_surface := game.surface_state(run_state, environment, deal_state)
	var dealt_channels: Array = dealt_surface.get("surface_animation_channels", []) if typeof(dealt_surface.get("surface_animation_channels", [])) == TYPE_ARRAY else []
	for channel_value in dealt_channels:
		var channel: Dictionary = channel_value if typeof(channel_value) == TYPE_DICTIONARY else {}
		if str(channel.get("id", "")) == "video_poker_flip" and int(channel.get("started_msec", 0)) <= 0:
			failures.append("Video poker flip channel did not preserve the positive DEAL animation start.")
	if str(dealt_surface.get("phase", "")) != "hold":
		failures.append("Video poker DEAL did not enter hold phase.")
	var hold_click := _check_surface_command_non_mutating(game, "video_poker_hold", 0, false, deal_state, run_state, environment, "video poker hold", failures)
	var hold_state: Dictionary = hold_click.get("ui_state", {})
	if not (hold_state.get("holds", []) as Array).has(0):
		failures.append("Video poker card click did not update UI-local hold state.")
	var draw_click := game.surface_action_command("video_poker_draw", 0, false, hold_state, run_state, environment)
	if str(draw_click.get("action_kind", "")) != "legal":
		failures.append("Video poker draw did not map to a legal action.")
	if not bool(draw_click.get("direct_resolve", false)):
		failures.append("Video poker DRAW still requires a second confirmation click.")
	var selected_surface := game.surface_state(run_state, environment, hold_state)
	if not (selected_surface.get("native_selected_surface_actions", []) as Array).is_empty():
		failures.append("Video poker surface should not expose native selected actions that can auto-advance play.")
	var hold_harness := SurfaceHarness.new()
	hold_harness.setup(selected_surface)
	game.draw_surface(hold_harness, selected_surface, {"contract_harness": true})
	_check_surface_hit_layout(hold_harness, "Video poker hold surface", failures)
	if not hold_harness.labels.has("HELD"):
		failures.append("Video poker hold surface did not render an unmistakable HELD state.")
	var hold_paytable_visible := false
	for label_value in hold_harness.labels:
		if str(label_value).begins_with("PAY TABLE"):
			hold_paytable_visible = true
	if not hold_paytable_visible:
		failures.append("Video poker renderer did not keep the paytable visible while selecting holds.")
	if _surface_hit_count(hold_harness, "video_poker_hold") < 5:
		failures.append("Video poker hold surface should expose one HOLD control per card.")
	if not _surface_harness_has_action(hold_harness, "video_poker_draw"):
		failures.append("Video poker hold surface is missing DRAW.")
	if not _surface_harness_has_action(hold_harness, "video_poker_mark"):
		failures.append("Video poker hold surface is missing the holdout MARK control.")
	var mark_click := game.surface_action_command("video_poker_mark", 0, false, deal_state, run_state, environment)
	if str(mark_click.get("action_kind", "")) != "cheat":
		failures.append("Video poker marked holds did not map to a risky action.")
	var mark_state: Dictionary = mark_click.get("ui_state", {})
	if not bool(mark_state.get("marked", false)):
		failures.append("Video poker mark did not arm the holdout cheat in UI-local state.")
	var mark_challenge: Dictionary = mark_state.get("holdout_challenge", {}) if typeof(mark_state.get("holdout_challenge", {})) == TYPE_DICTIONARY else {}
	if mark_challenge.is_empty():
		failures.append("Video poker mark did not create a timed holdout challenge.")
	else:
		var beats: Array = mark_challenge.get("beats", []) if typeof(mark_challenge.get("beats", [])) == TYPE_ARRAY else []
		if beats.size() != 2 or int(mark_challenge.get("chain_version", 0)) < 3:
			failures.append("Video poker holdout did not create the required two-beat LINE UP/COMMIT chain.")
	# The cheat's marked holds match the module's own suggested holds for the deal.
	var fresh_surface := game.surface_state(run_state, environment, deal_state)
	if JSON.stringify(mark_state.get("holds", [])) != JSON.stringify(fresh_surface.get("suggested_holds", [])):
		failures.append("Video poker mark did not set the suggested optimal holds.")
	var marked_surface := game.surface_state(run_state, environment, mark_state)
	var mark_harness := SurfaceHarness.new()
	mark_harness.setup(marked_surface)
	game.draw_surface(mark_harness, marked_surface, {"contract_harness": true})
	if not _surface_harness_has_action(mark_harness, "video_poker_palm"):
		failures.append("Video poker marked holdout surface is missing the timed holdout control.")
	if not bool(marked_surface.get("surface_realtime_state_refresh", false)):
		failures.append("Video poker marked holdout surface did not request realtime timing refresh.")
	var holdout_meter: Dictionary = marked_surface.get("holdout_meter", {}) if typeof(marked_surface.get("holdout_meter", {})) == TYPE_DICTIONARY else {}
	if not bool(holdout_meter.get("center_focus", false)):
		failures.append("Video poker holdout did not expose a center-screen minigame meter.")
	var sweep_ui := mark_state.duplicate(true)
	sweep_ui["surface_time_msec"] = int(mark_challenge.get("started_msec", 0)) + 240
	var sweep_surface := game.surface_state(run_state, environment, sweep_ui)
	var moved_meter: Dictionary = sweep_surface.get("holdout_meter", {}) if typeof(sweep_surface.get("holdout_meter", {})) == TYPE_DICTIONARY else {}
	if is_equal_approx(float(holdout_meter.get("progress", 0.0)), float(moved_meter.get("progress", 0.0))):
		failures.append("Video poker holdout sweep remained stationary across realtime surface updates.")
	var incomplete_draw := game.surface_action_command("video_poker_draw", 0, false, mark_state, run_state, environment)
	var incomplete_draw_ui: Dictionary = incomplete_draw.get("ui_state", {}) if typeof(incomplete_draw.get("ui_state", {})) == TYPE_DICTIONARY else {}
	var incomplete_challenge: Dictionary = incomplete_draw_ui.get("holdout_challenge", {}) if typeof(incomplete_draw_ui.get("holdout_challenge", {})) == TYPE_DICTIONARY else {}
	if str(incomplete_draw.get("action_id", "")) != "mark_holds" or not bool(incomplete_draw.get("direct_resolve", false)) or str(incomplete_challenge.get("skill_grade", "")) != "miss":
		failures.append("Video poker DRAW did not settle an unfinished holdout as a miss in one press.")
	var palm_state: Dictionary = _video_poker_complete_holdout_chain(game, run_state, mark_state, 0)
	var palm_challenge: Dictionary = palm_state.get("holdout_challenge", {}) if typeof(palm_state.get("holdout_challenge", {})) == TYPE_DICTIONARY else {}
	if str(palm_challenge.get("skill_grade", "")) != "perfect" or not bool(palm_challenge.get("chain_complete", false)):
		failures.append("Video poker LINE UP/COMMIT chain did not grade perfect timed inputs.")
	var cheat_draw := game.surface_action_command("video_poker_draw", 0, true, palm_state, run_state, environment)
	if str(cheat_draw.get("action_id", "")) != "mark_holds" or str(cheat_draw.get("action_kind", "")) != "cheat" or not bool(cheat_draw.get("direct_resolve", false)):
		failures.append("Video poker DRAW did not resolve the armed holdout cheat in one press.")
	var reduced_run: RunState = _vp_fresh(game, "jacks_or_better", "VIDEO-POKER-REDUCED-HOLDOUT", 5000)
	var reduced_deal := game.surface_action_command("video_poker_deal", 0, false, {"reduce_motion": true, "surface_time_msec": 41000}, reduced_run, reduced_run.current_environment)
	var reduced_mark := game.surface_action_command("video_poker_mark", 0, false, reduced_deal.get("ui_state", {}), reduced_run, reduced_run.current_environment)
	var reduced_ui: Dictionary = reduced_mark.get("ui_state", {})
	var reduced_surface := game.surface_state(reduced_run, reduced_run.current_environment, reduced_ui)
	var reduced_challenge: Dictionary = reduced_ui.get("holdout_challenge", {}) if typeof(reduced_ui.get("holdout_challenge", {})) == TYPE_DICTIONARY else {}
	var reduced_beats: Array = reduced_challenge.get("beats", []) if typeof(reduced_challenge.get("beats", [])) == TYPE_ARRAY else []
	if reduced_beats.size() != 1 or not bool(reduced_challenge.get("reduce_motion", false)):
		failures.append("Video poker reduce-motion holdout did not collapse to a single accessible input.")
	if bool(reduced_surface.get("surface_realtime_state_refresh", false)):
		failures.append("Video poker reduce-motion holdout still requested continuous realtime redraw.")


func _check_video_poker_bet_controls(game: GameModule, failures: Array) -> void:
	var run_state: RunState = _vp_fresh(game, "jacks_or_better", "VIDEO-POKER-BET-CONTROLS", 100000, "full_pay", 1, 1)
	var environment: Dictionary = run_state.current_environment
	environment["economic_profile"] = {"stake_floor": 1, "stake_ceiling": 200}
	run_state.current_environment = environment
	var ui: Dictionary = {"bet_level": 0, "denomination_index": 0}
	var wagers: Array[int] = []
	for expected_coin in range(1, 6):
		var bet_surface := game.surface_state(run_state, environment, ui)
		var wager := int(bet_surface.get("bet_credits", 0))
		wagers.append(wager)
		if int(bet_surface.get("coin_count", 0)) != expected_coin:
			failures.append("Video poker BET + did not reach %d coins per hand." % expected_coin)
			return
		if expected_coin < 5:
			var command := game.surface_action_command("video_poker_bet_one", 0, false, ui, run_state, environment)
			ui = command.get("ui_state", {}) if typeof(command.get("ui_state", {})) == TYPE_DICTIONARY else {}
	for index in range(1, wagers.size()):
		if wagers[index] <= wagers[index - 1]:
			failures.append("Video poker wager did not increase across the 1-5 coin ladder: %s." % JSON.stringify(wagers))
	var down := game.surface_action_command("video_poker_bet_down", 0, false, ui, run_state, environment)
	var down_ui: Dictionary = down.get("ui_state", {}) if typeof(down.get("ui_state", {})) == TYPE_DICTIONARY else {}
	var down_surface := game.surface_state(run_state, environment, down_ui)
	if int(down_surface.get("coin_count", 0)) != 4 or int(down_surface.get("bet_credits", 0)) >= int(wagers[4]):
		failures.append("Video poker BET - did not reduce a five-coin wager.")
	var max_command := game.surface_action_command("video_poker_bet_max", 0, false, {"bet_level": 0, "denomination_index": 0}, run_state, environment)
	var max_ui: Dictionary = max_command.get("ui_state", {}) if typeof(max_command.get("ui_state", {})) == TYPE_DICTIONARY else {}
	var max_surface := game.surface_state(run_state, environment, max_ui)
	if int(max_surface.get("coin_count", 0)) != 5 or int(max_surface.get("active_paytable_column", -1)) != 4:
		failures.append("Video poker BET MAX did not select five coins and the fifth paytable column.")
	if int(max_command.get("set_stake", 0)) != int(max_surface.get("bet_credits", -1)):
		failures.append("Video poker BET MAX command wager did not match the live BET meter.")
	var five_dollar_environment: Dictionary = environment.duplicate(true)
	five_dollar_environment["economic_profile"] = {"stake_floor": 1, "stake_ceiling": 20}
	var five_dollar_states: Dictionary = five_dollar_environment.get("game_states", {})
	var five_dollar_state: Dictionary = five_dollar_states.get("video_poker", {}).duplicate(true)
	five_dollar_state["coin_denominations"] = [{"label": "$5", "credits": 20}]
	five_dollar_state["denomination_index"] = 0
	five_dollar_state["multi_hand_count"] = 1
	five_dollar_states["video_poker"] = five_dollar_state
	five_dollar_environment["game_states"] = five_dollar_states
	run_state.current_environment = five_dollar_environment
	var five_dollar_max := game.surface_action_command("video_poker_bet_max", 0, false, {"bet_level": 0, "denomination_index": 0}, run_state, five_dollar_environment)
	var five_dollar_surface := game.surface_state(run_state, five_dollar_environment, five_dollar_max.get("ui_state", {}))
	if int(five_dollar_surface.get("coin_count", 0)) != 5 or int(five_dollar_surface.get("bet_credits", 0)) != 100:
		failures.append("Video poker $5 denomination did not allow all five coins despite sufficient bankroll.")


# Video poker is a full-simulation draw-poker module: hand evaluation, holds
# changing the outcome, the holdout cheat (odds + heat), the RTP band, and the
# result-visible guard against the surface stranding in the hold phase.
func _check_video_poker_contract(library: ContentLibrary, failures: Array) -> void:
	var game: GameModule = _load_surface_contract_game(library, "video_poker", failures)
	if game == null:
		return
	if not game.is_full_simulation():
		failures.append("Video Poker must report the full-simulation gameplay model.")
	_check_video_poker_evaluation(game, failures)
	_check_video_poker_paytable_variants(game, failures)
	_check_video_poker_generated_identity(game, failures)
	_check_video_poker_royal_bonus(game, failures)
	_check_video_poker_result_visible(game, failures)
	_check_video_poker_save_load_mid_hand(game, failures)
	_check_video_poker_holds_outcome(game, failures)
	_check_video_poker_multi_hand(game, failures)
	_check_video_poker_triple_denomination_cycle(game, failures)
	_check_video_poker_cheat(game, failures)
	_check_video_poker_item_luck_alcohol(game, failures)
	_check_video_poker_freds_hat(game, library, failures)
	_check_video_poker_double_up(game, failures)
	_check_video_poker_rtp_bands(game, failures)


func _vp_card(rank: int, suit: int) -> Dictionary:
	return {"rank": rank, "suit": suit, "deck": 0}


func _check_video_poker_freds_hat(game: GameModule, library: ContentLibrary, failures: Array) -> void:
	var item := library.item("freds_poker_hat")
	if item.is_empty():
		failures.append("Fred's Poker Hat item definition is missing.")
		return
	if str(item.get("rarity", "")) != "common" or int(item.get("price_max", 99)) > 12:
		failures.append("Fred's Poker Hat is not a cheap common item.")
	var effect: Dictionary = item.get("effect", {}) if typeof(item.get("effect", {})) == TYPE_DICTIONARY else {}
	if int(effect.get("video_poker_strategy_hint", 0)) != 1 or int(effect.get("video_poker_win_heat", 0)) != 1:
		failures.append("Fred's Poker Hat does not expose its strategy hint and +1 win Heat effects.")
	var group := library.content_group("video_poker_pack")
	if not _string_array(group.get("item_ids", [])).has("freds_poker_hat"):
		failures.append("Fred's Poker Hat is not reachable through the video-poker content pack.")

	var run_state: RunState = _vp_fresh(game, "jacks_or_better", "FREDS-HAT-SURFACE", 100000, "full_pay", 1, 1)
	var deal := game.surface_action_command("video_poker_deal", 0, false, {}, run_state, run_state.current_environment)
	var ui: Dictionary = deal.get("ui_state", {}) if typeof(deal.get("ui_state", {})) == TYPE_DICTIONARY else {}
	var bare_surface := game.surface_state(run_state, run_state.current_environment, ui)
	if bool(bare_surface.get("poker_hat_strategy_active", false)):
		failures.append("Video poker showed Fred's recommendation without owning the hat.")
	run_state.add_item("freds_poker_hat")
	var hat_surface := game.surface_state(run_state, run_state.current_environment, ui)
	var recommended: Array = hat_surface.get("recommended_holds", []) if typeof(hat_surface.get("recommended_holds", [])) == TYPE_ARRAY else []
	if not bool(hat_surface.get("poker_hat_strategy_active", false)) or str(hat_surface.get("recommended_hold_text", "")).is_empty():
		failures.append("Fred's Poker Hat did not expose a visible hold recommendation during the hold phase.")
	var harness := SurfaceHarness.new()
	harness.setup(hat_surface)
	game.draw_surface(harness, hat_surface, {"contract_harness": true})
	var saw_fred := false
	for label_value in harness.labels:
		if str(label_value).begins_with("FRED'S PICK"):
			saw_fred = true
			break
	if not saw_fred:
		failures.append("Fred's Poker Hat recommendation was not rendered on the video-poker machine.")
	var cache_size := int((game.get("_strategy_hold_cache") as Dictionary).size())
	var repeat_surface := game.surface_state(run_state, run_state.current_environment, ui)
	if JSON.stringify(recommended) != JSON.stringify(repeat_surface.get("recommended_holds", [])) or int((game.get("_strategy_hold_cache") as Dictionary).size()) != cache_size:
		failures.append("Fred's Poker Hat recommendation was not stable and cached across redraws.")

	var royal_draw := [_vp_card(10, 1), _vp_card(11, 1), _vp_card(12, 1), _vp_card(13, 1), _vp_card(4, 0)]
	var royal_variant := _vp_variant(game, "jacks_or_better")
	var royal_holds: Array = game.call("_best_odds_holds", royal_draw, royal_variant, {"progressive_meter": 300}, 5, 1, true)
	if JSON.stringify(royal_holds) != JSON.stringify([0, 1, 2, 3]):
		failures.append("Fred's Poker Hat did not recommend the four-card royal draw (got %s)." % JSON.stringify(royal_holds))

	var found_win := false
	var found_loss := false
	for seed_index in range(80):
		var heat_run: RunState = _vp_fresh(game, "jacks_or_better", "FREDS-HAT-HEAT-%d" % seed_index, 100000, "full_pay", 1, 1)
		heat_run.add_item("freds_poker_hat")
		var heat_result := game.resolve_with_context("draw", 1, heat_run, heat_run.current_environment, heat_run.create_rng("freds_hat_resolve"), {"hand_active": true, "holds": [], "bet_level": 0, "denomination_index": 0})
		if int(heat_result.get("video_poker_gross", 0)) > 0:
			found_win = true
			if int(heat_result.get("video_poker_poker_hat_heat", 0)) != 1 or int(heat_result.get("suspicion_delta", 0)) != 1:
				failures.append("Fred's Poker Hat did not add exactly 1 Heat to a legal video-poker win.")
				break
		else:
			found_loss = true
			if int(heat_result.get("video_poker_poker_hat_heat", -1)) != 0 or int(heat_result.get("suspicion_delta", -1)) != 0:
				failures.append("Fred's Poker Hat added Heat to a losing video-poker hand.")
				break
		if found_win and found_loss:
			break
	if not found_win or not found_loss:
		failures.append("Fred's Poker Hat win-Heat fixture did not observe both a win and a loss.")


func _vp_variant(game: GameModule, variant_id: String) -> Dictionary:
	return game.call("_variant", {"variant_id": variant_id})


func _vp_check_pay(game: GameModule, variant_id: String, hand: Array, expected_key: String, failures: Array) -> void:
	var variant: Dictionary = _vp_variant(game, variant_id)
	var descriptor: Dictionary = game.call("_evaluate", hand, variant.get("wild_ranks", []))
	var pay_row: Dictionary = game.call("_pay_for", descriptor, variant)
	if str(pay_row.get("key", "")) != expected_key:
		failures.append("Video poker [%s] scored a hand as '%s' instead of '%s'." % [variant_id, str(pay_row.get("key", "")), expected_key])


func _vp_pay_mult(game: GameModule, variant_id: String, hand: Array) -> int:
	var variant: Dictionary = _vp_variant(game, variant_id)
	var descriptor: Dictionary = game.call("_evaluate", hand, variant.get("wild_ranks", []))
	var pay_row: Dictionary = game.call("_pay_for", descriptor, variant)
	return int(pay_row.get("mult", 0))


func _vp_row_keys(variant: Dictionary) -> Array:
	var keys: Array = []
	for row_value in variant.get("rows", []):
		var row: Dictionary = row_value if typeof(row_value) == TYPE_DICTIONARY else {}
		keys.append(str(row.get("key", "")))
	return keys


func _check_video_poker_evaluation(game: GameModule, failures: Array) -> void:
	# Jacks or Better base hands (royal, wheel straight, low-pair no-pay).
	_vp_check_pay(game, "jacks_or_better", [_vp_card(14, 1), _vp_card(13, 1), _vp_card(12, 1), _vp_card(11, 1), _vp_card(10, 1)], "royal_flush", failures)
	_vp_check_pay(game, "jacks_or_better", [_vp_card(9, 1), _vp_card(8, 1), _vp_card(7, 1), _vp_card(6, 1), _vp_card(5, 1)], "straight_flush", failures)
	_vp_check_pay(game, "jacks_or_better", [_vp_card(9, 0), _vp_card(9, 1), _vp_card(9, 2), _vp_card(9, 3), _vp_card(2, 0)], "four_kind", failures)
	_vp_check_pay(game, "jacks_or_better", [_vp_card(9, 0), _vp_card(9, 1), _vp_card(9, 2), _vp_card(9, 3), _vp_card(14, 0)], "four_kind", failures)
	_vp_check_pay(game, "jacks_or_better", [_vp_card(5, 0), _vp_card(5, 1), _vp_card(5, 2), _vp_card(9, 0), _vp_card(9, 1)], "full_house", failures)
	_vp_check_pay(game, "jacks_or_better", [_vp_card(2, 2), _vp_card(5, 2), _vp_card(9, 2), _vp_card(11, 2), _vp_card(13, 2)], "flush", failures)
	_vp_check_pay(game, "jacks_or_better", [_vp_card(14, 0), _vp_card(2, 1), _vp_card(3, 2), _vp_card(4, 3), _vp_card(5, 0)], "straight", failures)
	_vp_check_pay(game, "jacks_or_better", [_vp_card(7, 0), _vp_card(7, 1), _vp_card(7, 2), _vp_card(4, 3), _vp_card(9, 0)], "three_kind", failures)
	_vp_check_pay(game, "jacks_or_better", [_vp_card(11, 0), _vp_card(11, 1), _vp_card(4, 2), _vp_card(4, 3), _vp_card(9, 0)], "two_pair", failures)
	_vp_check_pay(game, "jacks_or_better", [_vp_card(12, 0), _vp_card(12, 1), _vp_card(3, 2), _vp_card(5, 3), _vp_card(9, 0)], "jacks_or_better", failures)
	_vp_check_pay(game, "jacks_or_better", [_vp_card(6, 0), _vp_card(6, 1), _vp_card(3, 2), _vp_card(9, 3), _vp_card(13, 0)], "", failures)
	# Double Double Bonus quads with kickers (and two pair pays the reduced row).
	_vp_check_pay(game, "double_double_bonus", [_vp_card(14, 0), _vp_card(14, 1), _vp_card(14, 2), _vp_card(14, 3), _vp_card(2, 0)], "four_aces_kicker", failures)
	_vp_check_pay(game, "double_double_bonus", [_vp_card(14, 0), _vp_card(14, 1), _vp_card(14, 2), _vp_card(14, 3), _vp_card(9, 0)], "four_aces", failures)
	_vp_check_pay(game, "double_double_bonus", [_vp_card(3, 0), _vp_card(3, 1), _vp_card(3, 2), _vp_card(3, 3), _vp_card(14, 0)], "four_2_4_kicker", failures)
	_vp_check_pay(game, "double_double_bonus", [_vp_card(3, 0), _vp_card(3, 1), _vp_card(3, 2), _vp_card(3, 3), _vp_card(9, 0)], "four_2_4", failures)
	_vp_check_pay(game, "double_double_bonus", [_vp_card(11, 0), _vp_card(11, 1), _vp_card(4, 2), _vp_card(4, 3), _vp_card(9, 0)], "two_pair", failures)
	# Deuces Wild wild-card categories.
	_vp_check_pay(game, "deuces_wild", [_vp_card(14, 1), _vp_card(13, 1), _vp_card(12, 1), _vp_card(11, 1), _vp_card(10, 1)], "natural_royal", failures)
	_vp_check_pay(game, "deuces_wild", [_vp_card(2, 0), _vp_card(2, 1), _vp_card(2, 2), _vp_card(2, 3), _vp_card(9, 0)], "four_deuces", failures)
	_vp_check_pay(game, "deuces_wild", [_vp_card(2, 1), _vp_card(13, 1), _vp_card(12, 1), _vp_card(11, 1), _vp_card(10, 1)], "wild_royal", failures)
	_vp_check_pay(game, "deuces_wild", [_vp_card(2, 0), _vp_card(2, 1), _vp_card(13, 0), _vp_card(13, 1), _vp_card(13, 2)], "five_kind", failures)
	_vp_check_pay(game, "deuces_wild", [_vp_card(2, 0), _vp_card(7, 0), _vp_card(8, 0), _vp_card(9, 0), _vp_card(10, 0)], "straight_flush", failures)
	_vp_check_pay(game, "deuces_wild", [_vp_card(2, 0), _vp_card(7, 0), _vp_card(7, 1), _vp_card(7, 2), _vp_card(9, 0)], "four_kind", failures)
	_vp_check_pay(game, "deuces_wild", [_vp_card(2, 0), _vp_card(5, 0), _vp_card(8, 0), _vp_card(11, 0), _vp_card(13, 0)], "flush", failures)
	_vp_check_pay(game, "deuces_wild", [_vp_card(2, 0), _vp_card(7, 1), _vp_card(8, 2), _vp_card(9, 3), _vp_card(10, 0)], "straight", failures)
	_vp_check_pay(game, "deuces_wild", [_vp_card(2, 0), _vp_card(7, 1), _vp_card(7, 2), _vp_card(9, 3), _vp_card(11, 0)], "three_kind", failures)
	_vp_check_pay(game, "deuces_wild", [_vp_card(7, 0), _vp_card(7, 1), _vp_card(9, 3), _vp_card(11, 0), _vp_card(13, 2)], "", failures)
func _check_video_poker_paytable_variants(game: GameModule, failures: Array) -> void:
	var jacks_keys: Array = _vp_row_keys(_vp_variant(game, "jacks_or_better"))
	for variant_id in ["double_double_bonus", "deuces_wild"]:
		var variant_keys: Array = _vp_row_keys(_vp_variant(game, variant_id))
		if JSON.stringify(variant_keys) == JSON.stringify(jacks_keys):
			failures.append("Video poker %s paytable is a reskin of Jacks or Better." % variant_id)
	var ace_quads := [_vp_card(14, 0), _vp_card(14, 1), _vp_card(14, 2), _vp_card(14, 3), _vp_card(9, 0)]
	if _vp_pay_mult(game, "jacks_or_better", ace_quads) != 25:
		failures.append("Video poker Jacks or Better four aces did not use the base quad payout.")
	if _vp_pay_mult(game, "double_double_bonus", ace_quads) != 160:
		failures.append("Video poker Double Double Bonus four aces did not use its variant payout.")
	var ace_quads_kicker := [_vp_card(14, 0), _vp_card(14, 1), _vp_card(14, 2), _vp_card(14, 3), _vp_card(2, 0)]
	if _vp_pay_mult(game, "double_double_bonus", ace_quads_kicker) != 400:
		failures.append("Video poker Double Double Bonus four aces with kicker did not use the kicker payout.")
	var two_pair := [_vp_card(11, 0), _vp_card(11, 1), _vp_card(4, 2), _vp_card(4, 3), _vp_card(9, 0)]
	if _vp_pay_mult(game, "jacks_or_better", two_pair) != 2 or _vp_pay_mult(game, "double_double_bonus", two_pair) != 1:
		failures.append("Video poker two-pair payout did not differ between Jacks or Better and Double Double Bonus.")
	var deuces_quads := [_vp_card(2, 0), _vp_card(2, 1), _vp_card(2, 2), _vp_card(2, 3), _vp_card(9, 0)]
	if _vp_pay_mult(game, "deuces_wild", deuces_quads) != 200:
		failures.append("Video poker Deuces Wild did not use the four-deuces paytable row.")
func _check_video_poker_generated_identity(game: GameModule, failures: Array) -> void:
	var run_a: RunState = RunStateScript.new()
	run_a.start_new("VIDEO-POKER-GENERATED")
	var env_a := _surface_contract_environment()
	var state_a: Dictionary = game.generate_environment_state(run_a, env_a, run_a.create_rng("video_poker_identity"))
	var run_b: RunState = RunStateScript.new()
	run_b.start_new("VIDEO-POKER-GENERATED")
	var env_b := _surface_contract_environment()
	var state_b: Dictionary = game.generate_environment_state(run_b, env_b, run_b.create_rng("video_poker_identity"))
	if JSON.stringify(state_a) != JSON.stringify(state_b):
		failures.append("Video poker generated cabinet identity is not deterministic for the same seed.")
	for required_key in ["cabinet_id", "cabinet_key", "variant_id", "paytable_tier_id", "coin_denominations", "denomination_index", "multi_hand_count", "progressive_meter", "holdout_tell"]:
		if not state_a.has(required_key):
			failures.append("Video poker generated state is missing %s." % required_key)
	var denominations: Array = state_a.get("coin_denominations", [])
	if denominations.is_empty():
		failures.append("Video poker generated no playable denomination.")
	var expected_hands := {"jacks_or_better": 1, "double_deuces": 2, "triple_double_bonus": 3}
	var cabinet_id := str(state_a.get("cabinet_id", ""))
	if not expected_hands.has(cabinet_id):
		failures.append("Video poker generated a retired cabinet id: %s." % cabinet_id)
	elif int(state_a.get("multi_hand_count", 0)) != int(expected_hands.get(cabinet_id, 0)):
		failures.append("Video poker generated cabinet %s with the wrong hand count." % cabinet_id)
	env_a["game_states"] = {"video_poker": state_a}
	run_a.current_environment = env_a.duplicate(true)
	var surface := game.surface_state(run_a, run_a.current_environment, {})
	if str(surface.get("surface_renderer", "")) != "card_machine":
		failures.append("Video poker generated surface did not route to the card-machine renderer.")
	if bool(surface.get("surface_stake_controls_required", true)):
		failures.append("Video poker should use cabinet coin controls instead of host stake controls.")
	if int(surface.get("hand_count", 0)) != int(state_a.get("multi_hand_count", 0)):
		failures.append("Video poker surface did not expose generated Play count.")
	var denom_click := _check_surface_command_non_mutating(game, "video_poker_denom", 0, false, {}, run_a, run_a.current_environment, "video poker denomination", failures)
	if int((denom_click.get("ui_state", {}) as Dictionary).get("denomination_index", -1)) == int(surface.get("denomination_index", 0)) and denominations.size() > 1:
		failures.append("Video poker denomination click did not update UI-local denomination state.")


func _check_video_poker_royal_bonus(game: GameModule, failures: Array) -> void:
	var variant: Dictionary = _vp_variant(game, "jacks_or_better")
	var rows: Array = variant.get("rows", [])
	if rows.is_empty():
		failures.append("Video poker variant exposed no paytable rows.")
		return
	var royal_row: Dictionary = rows[0]
	# Below max coin the royal pays 250-for-1; at 5 coins it pays 800-for-1.
	var pay_low := int(game.call("_row_pay", royal_row, 4, false))
	var pay_max := int(game.call("_row_pay", royal_row, 5, true))
	if pay_low != 1000:
		failures.append("Video poker royal did not pay 250-for-1 below the max bet (got %d)." % pay_low)
	if pay_max != 4000:
		failures.append("Video poker royal did not pay the 800-for-1 max-bet jackpot (got %d)." % pay_max)
	var full_variant: Dictionary = game.call("_variant", {"variant_id": "jacks_or_better", "paytable_tier_id": "full_pay"})
	var short_variant: Dictionary = game.call("_variant", {"variant_id": "jacks_or_better", "paytable_tier_id": "short_pay"})
	var full_house_full: Dictionary = game.call("_pay_for", game.call("_evaluate", [_vp_card(5, 0), _vp_card(5, 1), _vp_card(5, 2), _vp_card(9, 0), _vp_card(9, 1)], []), full_variant)
	var full_house_short: Dictionary = game.call("_pay_for", game.call("_evaluate", [_vp_card(5, 0), _vp_card(5, 1), _vp_card(5, 2), _vp_card(9, 0), _vp_card(9, 1)], []), short_variant)
	if int(full_house_full.get("mult", 0)) <= int(full_house_short.get("mult", 0)):
		failures.append("Video poker full-pay tier did not outrank short-pay full house.")


func _vp_fresh(game: GameModule, variant_id: String, seed_text: String, bankroll: int, tier_id: String = "standard", hand_count: int = 1, coin_value: int = 1) -> RunState:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed_text)
	run_state.bankroll = bankroll
	var environment := _surface_contract_environment()
	environment["economic_profile"] = {"stake_floor": 1, "stake_ceiling": maxi(20, coin_value * hand_count * 5)}
	var state: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("vp_state"))
	match variant_id:
		"deuces_wild":
			state["cabinet_id"] = "double_deuces"
		"double_double_bonus":
			state["cabinet_id"] = "triple_double_bonus"
		_:
			state["cabinet_id"] = "jacks_or_better"
	state["variant_id"] = variant_id
	state["paytable_tier_id"] = tier_id
	state["coin_denominations"] = [{"label": "$%d" % coin_value, "credits": coin_value}]
	state["denomination_index"] = 0
	state["multi_hand_count"] = hand_count
	state["progressive_meter"] = 300
	environment["game_states"] = {"video_poker": state}
	run_state.current_environment = environment.duplicate(true)
	return run_state


func _check_video_poker_triple_denomination_cycle(game: GameModule, failures: Array) -> void:
	var run_state: RunState = _vp_fresh(game, "double_double_bonus", "VIDEO-POKER-TRIPLE-DENOM", 1000, "full_pay", 3, 3)
	var environment: Dictionary = run_state.current_environment
	environment["economic_profile"] = {"stake_floor": 1, "stake_ceiling": 20}
	var game_states: Dictionary = environment.get("game_states", {})
	var state: Dictionary = game_states.get("video_poker", {})
	state["cabinet_id"] = "triple_double_bonus"
	state["variant_id"] = "double_double_bonus"
	state["multi_hand_count"] = 3
	state["coin_denominations"] = [
		{"label": "50c", "credits": 3},
		{"label": "$1", "credits": 6},
	]
	state["denomination_index"] = 0
	game_states["video_poker"] = state
	environment["game_states"] = game_states
	run_state.current_environment = environment
	var command: Dictionary = game.surface_action_command("video_poker_denom", 0, false, {"denomination_index": 0, "bet_level": 0}, run_state, environment)
	var command_ui: Dictionary = command.get("ui_state", {}) if typeof(command.get("ui_state", {})) == TYPE_DICTIONARY else {}
	var changed_surface: Dictionary = game.surface_state(run_state, environment, command_ui)
	if int(command_ui.get("denomination_index", -1)) != 1 or str(changed_surface.get("coin_label", "")) != "$1":
		failures.append("Triple Double Bonus could not change away from its playable 50c denomination.")
	if int(changed_surface.get("coin_count", 0)) != 1 or int(changed_surface.get("bet_credits", 0)) != 18:
		failures.append("Triple Double Bonus did not preserve its selected one-coin wager when changing denomination.")
	var triple_max := game.surface_action_command("video_poker_bet_max", 0, false, command_ui, run_state, environment)
	var triple_max_surface := game.surface_state(run_state, environment, triple_max.get("ui_state", {}))
	if int(triple_max_surface.get("coin_count", 0)) != 5 or int(triple_max_surface.get("bet_credits", 0)) != 90:
		failures.append("Triple Double Bonus denomination remained incorrectly capped by the room limit despite sufficient bankroll.")


func _check_video_poker_result_visible(game: GameModule, failures: Array) -> void:
	var run_state: RunState = _vp_fresh(game, "jacks_or_better", "VIDEO-POKER-RESULT-VISIBLE", 500)
	var deal_cmd := game.surface_action_command("video_poker_deal", 0, false, {}, run_state, run_state.current_environment)
	var dealt_ui: Dictionary = deal_cmd.get("ui_state", {})
	# One DRAW press must resolve and must NOT preserve UI-local state, so the host
	# clears the active hand and the next surface_state shows the settled result.
	var confirm_cmd := game.surface_action_command("video_poker_draw", 0, true, dealt_ui, run_state, run_state.current_environment)
	if not bool(confirm_cmd.get("direct_resolve", false)):
		failures.append("Video poker DRAW did not request immediate resolution.")
	if bool(confirm_cmd.get("preserve_surface_ui_state", false)):
		failures.append("Video poker resolving draw preserved UI-local state, stranding the surface in the hold phase.")
	var result := game.resolve_with_context("draw", 8, run_state, run_state.current_environment, run_state.create_rng("vp_visible_resolve"), confirm_cmd.get("ui_state", dealt_ui))
	if not bool(result.get("ok", false)):
		failures.append("Video poker draw did not complete a hand.")
	var settled := game.surface_state(run_state, run_state.current_environment, {})
	if str(settled.get("phase", "")) != "settled":
		failures.append("Video poker surface did not show the settled result after drawing (phase=%s)." % str(settled.get("phase", "")))
	if str(settled.get("result_message", "")).strip_edges().is_empty():
		failures.append("Video poker settled surface did not expose the hand result after drawing.")
	var settled_harness := SurfaceHarness.new()
	settled_harness.setup(settled)
	game.draw_surface(settled_harness, settled, {"contract_harness": true})
	if _surface_harness_has_action(settled_harness, "video_poker_collect"):
		failures.append("Video poker settled surface still exposes a manual COLLECT action instead of automatic payout.")


func _check_video_poker_save_load_mid_hand(game: GameModule, failures: Array) -> void:
	var run_state: RunState = _vp_fresh(game, "jacks_or_better", "VIDEO-POKER-SAVE-MID-HAND", 5000)
	var deal_cmd := game.surface_action_command("video_poker_deal", 0, false, {}, run_state, run_state.current_environment)
	var ui: Dictionary = deal_cmd.get("ui_state", {})
	ui["holds"] = [1, 3]
	ui["bet_level"] = 2
	ui["surface_time_msec"] = 32000
	var saved_run: Dictionary = run_state.to_dict()
	var restored: RunState = RunStateScript.new()
	restored.from_dict(saved_run)
	var parsed_ui: Variant = JSON.parse_string(JSON.stringify(ui))
	var restored_ui: Dictionary = parsed_ui if typeof(parsed_ui) == TYPE_DICTIONARY else {}
	var restored_surface := game.surface_state(restored, restored.current_environment, restored_ui)
	if str(restored_surface.get("phase", "")) != "hold":
		failures.append("Video poker save/load mid-hand did not restore the hold phase.")
	var restored_holds: Array = restored_surface.get("holds", [])
	if JSON.stringify(restored_holds) != JSON.stringify([1, 3]):
		failures.append("Video poker save/load mid-hand did not preserve held-card selections.")
	if int(restored_surface.get("bet_level", -1)) != 2 or int(restored_surface.get("active_paytable_column", -1)) != 2:
		failures.append("Video poker save/load mid-hand did not preserve the wager and highlighted paytable column.")
	var result := game.resolve_with_context("draw", 0, restored, restored.current_environment, restored.create_rng("vp_save_restore_draw"), restored_ui)
	if not bool(result.get("ok", false)) or (result.get("video_poker_hand", []) as Array).size() != 5:
		failures.append("Video poker restored mid-hand state could not resolve a valid draw.")


func _check_video_poker_holds_outcome(game: GameModule, failures: Array) -> void:
	# Holding all five cards (no draw) versus holding none (draw all five) from the
	# same deal must produce different final hands, proving holds change the outcome.
	var hold_all := _video_poker_resolve_with_holds(game, [0, 1, 2, 3, 4])
	var hold_none := _video_poker_resolve_with_holds(game, [])
	var kept: Array = hold_all.get("video_poker_hand", [])
	var drawn: Array = hold_none.get("video_poker_hand", [])
	if kept.size() != 5 or drawn.size() != 5:
		failures.append("Video poker resolve did not report a final hand.")
		return
	if JSON.stringify(kept) == JSON.stringify(drawn):
		failures.append("Video poker holds did not change the drawn hand.")


func _video_poker_resolve_with_holds(game: GameModule, holds: Array) -> Dictionary:
	var run_state: RunState = _vp_fresh(game, "jacks_or_better", "VIDEO-POKER-HOLDS", 100000)
	var deal_cmd := game.surface_action_command("video_poker_deal", 0, false, {}, run_state, run_state.current_environment)
	var ui: Dictionary = deal_cmd.get("ui_state", {})
	ui["holds"] = holds
	return game.resolve_with_context("draw", 5, run_state, run_state.current_environment, run_state.create_rng("vp_holds_resolve"), ui)


func _video_poker_holdout_timed_ui(game: GameModule, run_state: RunState, base_ui: Dictionary, margin_msec: int = 0) -> Dictionary:
	var ui: Dictionary = base_ui.duplicate(true)
	ui["surface_time_msec"] = int(ui.get("surface_time_msec", 12000))
	var mark_cmd: Dictionary = game.surface_action_command("video_poker_mark", 0, false, ui, run_state, run_state.current_environment)
	var mark_ui: Dictionary = mark_cmd.get("ui_state", ui)
	return _video_poker_complete_holdout_chain(game, run_state, mark_ui, margin_msec)


func _video_poker_complete_holdout_chain(game: GameModule, run_state: RunState, mark_ui: Dictionary, margin_msec: int = 0) -> Dictionary:
	var ui: Dictionary = mark_ui.duplicate(true)
	var safety := 0
	while safety < 5:
		safety += 1
		var challenge: Dictionary = ui.get("holdout_challenge", {}) if typeof(ui.get("holdout_challenge", {})) == TYPE_DICTIONARY else {}
		var beats: Array = challenge.get("beats", []) if typeof(challenge.get("beats", [])) == TYPE_ARRAY else []
		if bool(challenge.get("chain_complete", false)) or not str(challenge.get("skill_grade", "")).is_empty():
			break
		if beats.is_empty():
			ui["holdout_input_msec"] = int(challenge.get("perfect_msec", int(ui.get("surface_time_msec", 12000)))) + margin_msec
			var legacy_cmd: Dictionary = game.surface_action_command("video_poker_palm", 0, false, ui, run_state, run_state.current_environment)
			ui = legacy_cmd.get("ui_state", ui)
			break
		var beat_index := clampi(int(challenge.get("current_beat", 0)), 0, maxi(0, beats.size() - 1))
		var beat: Dictionary = beats[beat_index] if typeof(beats[beat_index]) == TYPE_DICTIONARY else {}
		var index := int(challenge.get("target_slot", 0)) if str(beat.get("kind", "")) == "target" else 0
		ui["holdout_input_msec"] = int(beat.get("target_msec", int(ui.get("surface_time_msec", 12000)))) + margin_msec
		ui["surface_time_msec"] = int(ui["holdout_input_msec"])
		var palm_cmd: Dictionary = game.surface_action_command("video_poker_palm", index, false, ui, run_state, run_state.current_environment)
		ui = palm_cmd.get("ui_state", ui)
	return ui


func _check_video_poker_multi_hand(game: GameModule, failures: Array) -> void:
	var run_state: RunState = _vp_fresh(game, "double_double_bonus", "VIDEO-POKER-MULTI", 1000000, "full_pay", 3, 1)
	var deal_cmd := game.surface_action_command("video_poker_deal", 0, false, {"surface_time_msec": 42000}, run_state, run_state.current_environment)
	var ui: Dictionary = deal_cmd.get("ui_state", {})
	var dealt_surface := game.surface_state(run_state, run_state.current_environment, ui)
	var deal_channels: Array = dealt_surface.get("surface_animation_channels", []) if typeof(dealt_surface.get("surface_animation_channels", [])) == TYPE_ARRAY else []
	for channel_value in deal_channels:
		var channel: Dictionary = channel_value if typeof(channel_value) == TYPE_DICTIONARY else {}
		if ["video_poker_flip", "video_poker_cascade"].has(str(channel.get("id", ""))) and str(channel.get("clock_source", "")) != "surface":
			failures.append("Video poker three-hand animation used the engine clock instead of the pause-safe surface clock.")
	ui["holds"] = [0, 1]
	ui["bet_level"] = 4
	var result := game.resolve_with_context("draw", 5, run_state, run_state.current_environment, run_state.create_rng("vp_multi_resolve"), ui)
	var hands: Array = result.get("video_poker_hands", [])
	var hand_results: Array = result.get("video_poker_hand_results", [])
	if hands.size() != 3 or hand_results.size() != 3:
		failures.append("Video poker Triple Double Bonus did not resolve three independent hands.")
		return
	var first_hand: Array = hands[0]
	var distinct_hands := {}
	var total := 0
	for i in range(hand_results.size()):
		var row: Dictionary = hand_results[i] if typeof(hand_results[i]) == TYPE_DICTIONARY else {}
		total += int(row.get("total", 0))
		var hand: Array = hands[i] if typeof(hands[i]) == TYPE_ARRAY else []
		if hand.size() != 5 or not _video_poker_hand_unique(hand):
			failures.append("Video poker multi-hand draw produced an invalid or duplicated-card hand.")
		if hand.size() >= 2 and first_hand.size() >= 2:
			if JSON.stringify([hand[0], hand[1]]) != JSON.stringify([first_hand[0], first_hand[1]]):
				failures.append("Video poker multi-hand did not replicate held cards across hands.")
		if str(row.get("draw_deck_rule", "")) != "independent_deck_minus_held":
			failures.append("Video poker multi-hand result did not report the independent deck-minus-held rule.")
		if int(row.get("draw_pool_size", 0)) != 50:
			failures.append("Video poker multi-hand draw pool was not 52 minus the two held cards.")
		var removed_cards: Array = row.get("draw_removed_cards", []) if typeof(row.get("draw_removed_cards", [])) == TYPE_ARRAY else []
		if removed_cards.size() != 2 or JSON.stringify(removed_cards) != JSON.stringify([first_hand[0], first_hand[1]]):
			failures.append("Video poker multi-hand draw did not remove exactly the held cards from each independent deck.")
		distinct_hands[JSON.stringify(hand)] = true
	if total != int(result.get("video_poker_gross", -1)):
		failures.append("Video poker multi-hand gross did not equal the sum of hand results.")
	if distinct_hands.size() <= 1:
		failures.append("Video poker multi-hand draws did not show independent per-hand decks.")
	if int(result.get("video_poker_bet", 0)) != 15:
		failures.append("Video poker 3-hand max-coin denomination math was wrong.")
	var settled_surface := game.surface_state(run_state, run_state.current_environment, {})
	if int(settled_surface.get("win_credits", -1)) != total:
		failures.append("Video poker WIN meter did not show the gross payout summed across hands.")
	var display_hands: Array = settled_surface.get("display_hands", []) if typeof(settled_surface.get("display_hands", [])) == TYPE_ARRAY else []
	var rendered_signatures: Array = settled_surface.get("rendered_hand_signatures", []) if typeof(settled_surface.get("rendered_hand_signatures", [])) == TYPE_ARRAY else []
	var distinct_rendered := {}
	for signature_value in rendered_signatures:
		distinct_rendered[str(signature_value)] = true
	if display_hands.size() != 3 or rendered_signatures.size() != 3 or distinct_rendered.size() != 3:
		failures.append("Video poker settled renderer state did not expose three visibly distinct Triple Double Bonus hands.")
	var settled_harness := SurfaceHarness.new()
	settled_harness.setup(settled_surface)
	game.draw_surface(settled_harness, settled_surface, {"contract_harness": true})
	for hand_number in range(1, 4):
		var rendered_label := false
		for label_value in settled_harness.labels:
			if str(label_value).begins_with("HAND %d" % hand_number):
				rendered_label = true
				break
		if not rendered_label:
			failures.append("Video poker renderer did not draw visible HAND %d content." % hand_number)
	_check_video_poker_multi_hand_many_seeds(game, failures)


func _check_video_poker_multi_hand_many_seeds(game: GameModule, failures: Array) -> void:
	var copied_draws := 0
	var invalid_results := 0
	for seed_index in range(36):
		var hands := 2 if seed_index % 2 == 0 else 3
		var variant := "deuces_wild" if hands == 2 else "double_double_bonus"
		var run_state: RunState = _vp_fresh(game, variant, "VIDEO-POKER-MULTI-SEED-%02d" % seed_index, 1000000, "full_pay", hands, 1)
		var deal_cmd := game.surface_action_command("video_poker_deal", 0, false, {}, run_state, run_state.current_environment)
		var ui: Dictionary = deal_cmd.get("ui_state", {})
		ui["holds"] = [0, 2]
		ui["bet_level"] = 4
		var result := game.resolve_with_context("draw", 5, run_state, run_state.current_environment, run_state.create_rng("vp_multi_seed_resolve"), ui)
		var resolved_hands: Array = result.get("video_poker_hands", []) if typeof(result.get("video_poker_hands", [])) == TYPE_ARRAY else []
		var hand_results: Array = result.get("video_poker_hand_results", []) if typeof(result.get("video_poker_hand_results", [])) == TYPE_ARRAY else []
		if resolved_hands.size() != hands or hand_results.size() != hands:
			invalid_results += 1
			continue
		var distinct := {}
		for hand_index in range(resolved_hands.size()):
			var hand: Array = resolved_hands[hand_index] if typeof(resolved_hands[hand_index]) == TYPE_ARRAY else []
			if hand.size() != 5 or not _video_poker_hand_unique(hand):
				invalid_results += 1
			if hand.size() >= 3 and JSON.stringify([hand[0], hand[2]]) != JSON.stringify([resolved_hands[0][0], resolved_hands[0][2]]):
				invalid_results += 1
			distinct[JSON.stringify([hand[1], hand[3], hand[4]])] = true
			var row: Dictionary = hand_results[hand_index] if typeof(hand_results[hand_index]) == TYPE_DICTIONARY else {}
			if str(row.get("draw_deck_rule", "")) != "independent_deck_minus_held" or int(row.get("draw_pool_size", 0)) != 50:
				invalid_results += 1
		if distinct.size() <= 1:
			copied_draws += 1
	if invalid_results > 0:
		failures.append("Video poker many-seed multi-hand proof found %d invalid independent draw results." % invalid_results)
	if copied_draws > 1:
		failures.append("Video poker many-seed multi-hand proof saw copied draw signatures in %d seeds." % copied_draws)


func _video_poker_hand_unique(hand: Array) -> bool:
	var seen := {}
	for card_value in hand:
		var card: Dictionary = card_value if typeof(card_value) == TYPE_DICTIONARY else {}
		var key := "%d:%d:%d" % [int(card.get("rank", 0)), int(card.get("suit", -1)), int(card.get("deck", 0))]
		if seen.has(key):
			return false
		seen[key] = true
	return true


func _check_video_poker_cheat(game: GameModule, failures: Array) -> void:
	var run_state: RunState = _vp_fresh(game, "jacks_or_better", "VIDEO-POKER-CHEAT", 100000)
	var before := _run_state_result_snapshot(run_state)
	var deal_cmd := game.surface_action_command("video_poker_deal", 0, false, {}, run_state, run_state.current_environment)
	var ui: Dictionary = _video_poker_holdout_timed_ui(game, run_state, deal_cmd.get("ui_state", {}), 0)
	var cheat_result := game.resolve_with_context("mark_holds", 5, run_state, run_state.current_environment, run_state.create_rng("vp_cheat_resolve"), ui)
	_check_action_result_shape(cheat_result, "cheat", failures)
	if int(cheat_result.get("suspicion_delta", 0)) <= 0:
		failures.append("Video poker holdout did not raise suspicion heat.")
	if not bool(cheat_result.get("video_poker_cheated", false)):
		failures.append("Video poker holdout did not flag the result as cheated.")
	if str(cheat_result.get("skill_grade", "")) != "perfect" or str(cheat_result.get("skill_outcome", "")) != "holdout_perfect":
		failures.append("Video poker holdout did not report the graded perfect skill outcome.")
	if not bool(cheat_result.get("video_poker_holdout_applied", false)):
		failures.append("Video poker perfect holdout did not apply the palm-and-swap payoff.")
	if str(cheat_result.get("video_poker_blunt_feedback", "")).find("RESULT:") < 0 or typeof(cheat_result.get("video_poker_holdout_target_card", {})) != TYPE_DICTIONARY:
		failures.append("Video poker holdout did not expose blunt swap-card/result feedback.")
	var target_slot := int(cheat_result.get("video_poker_holdout_target_slot", -1))
	var committed_card: Dictionary = cheat_result.get("video_poker_holdout_target_card", {}) if typeof(cheat_result.get("video_poker_holdout_target_card", {})) == TYPE_DICTIONARY else {}
	var cheat_hand: Array = cheat_result.get("video_poker_hand", [])
	var landed_card: Dictionary = cheat_hand[target_slot] if target_slot >= 0 and target_slot < cheat_hand.size() and typeof(cheat_hand[target_slot]) == TYPE_DICTIONARY else {}
	if not bool(game.call("_same_card", committed_card, landed_card)):
		failures.append("Video poker holdout feedback named a card that was not inserted into the promised final-hand slot.")
	var cheat_environment: Dictionary = cheat_result.get("environment", run_state.current_environment) if typeof(cheat_result.get("environment", run_state.current_environment)) == TYPE_DICTIONARY else run_state.current_environment
	var cheat_surface := game.surface_state(run_state, cheat_environment, {})
	var target_name := str(game.call("_card_name", committed_card)).to_upper()
	var result_detail := str(cheat_surface.get("result_detail", ""))
	if result_detail.find("SWAPPED IN %s" % target_name) < 0 or result_detail.find("RESULT:") < 0:
		failures.append("Video poker settled cabinet did not visibly name the holdout card and resulting hand.")
	var cheat_harness := SurfaceHarness.new()
	cheat_harness.setup(cheat_surface)
	game.draw_surface(cheat_harness, cheat_surface, {"contract_harness": true})
	var rendered_blunt_feedback := false
	for label_value in cheat_harness.labels:
		var rendered_label := str(label_value)
		if rendered_label.find("SWAPPED IN %s" % target_name) >= 0 and rendered_label.find("RESULT:") >= 0:
			rendered_blunt_feedback = true
			break
	if not rendered_blunt_feedback:
		failures.append("Video poker renderer did not draw the blunt holdout result beat.")
	if typeof(cheat_result.get("skill_story_context", {})) != TYPE_DICTIONARY or int((cheat_result.get("skill_story_context", {}) as Dictionary).get("skill_margin_msec", 999)) != 0:
		failures.append("Video poker holdout did not expose the shared skill story context with timing margin.")
	_check_action_result_application_contract(before, run_state, cheat_result, "video poker holdout result", failures)
	var direct_run: RunState = _vp_fresh(game, "jacks_or_better", "VIDEO-POKER-CHEAT-DIRECT", 100000)
	var direct_deal := game.surface_action_command("video_poker_deal", 0, false, {}, direct_run, direct_run.current_environment)
	var direct_result := game.resolve_with_context("mark_holds", 5, direct_run, direct_run.current_environment, direct_run.create_rng("vp_direct_cheat"), direct_deal.get("ui_state", {}))
	if bool(direct_result.get("video_poker_holdout_applied", false)) or str(direct_result.get("skill_grade", "")) != "miss":
		failures.append("Video poker mark_holds without a completed timed holdout granted an ungraded payoff.")
	if int(direct_result.get("suspicion_delta", 0)) <= 0 or direct_run.suspicion_level() <= 0:
		failures.append("Video poker abandoned holdout resolved without applying its miss-grade Heat.")
	var deterministic_a: RunState = _vp_fresh(game, "jacks_or_better", "VIDEO-POKER-CHEAT-DETERMINISTIC", 100000)
	var deterministic_b: RunState = _vp_fresh(game, "jacks_or_better", "VIDEO-POKER-CHEAT-DETERMINISTIC", 100000)
	var det_deal_a := game.surface_action_command("video_poker_deal", 0, false, {"surface_time_msec": 20000}, deterministic_a, deterministic_a.current_environment)
	var det_deal_b := game.surface_action_command("video_poker_deal", 0, false, {"surface_time_msec": 20000}, deterministic_b, deterministic_b.current_environment)
	var det_ui_a: Dictionary = _video_poker_holdout_timed_ui(game, deterministic_a, det_deal_a.get("ui_state", {"surface_time_msec": 20000}), 0)
	var det_ui_b: Dictionary = _video_poker_holdout_timed_ui(game, deterministic_b, det_deal_b.get("ui_state", {"surface_time_msec": 20000}), 0)
	if JSON.stringify(det_ui_a.get("holdout_challenge", {})) != JSON.stringify(det_ui_b.get("holdout_challenge", {})):
		failures.append("Video poker holdout challenge did not start deterministically from the same seeded input.")
	var round_trip_state: Dictionary = JSON.parse_string(JSON.stringify(det_ui_a))
	var round_trip_surface := game.surface_state(deterministic_a, deterministic_a.current_environment, round_trip_state)
	if typeof(round_trip_surface.get("holdout_challenge", {})) != TYPE_DICTIONARY or (round_trip_surface.get("holdout_challenge", {}) as Dictionary).is_empty():
		failures.append("Video poker holdout UI state did not survive save/load-style serialization mid-challenge.")
	# Over many hands the holdout improves the return-to-player versus honest play.
	var honest_rtp := _video_poker_rtp(game, "jacks_or_better", "standard", "draw", "VIDEO-POKER-CHEAT-HONEST", 600)
	var cheat_rtp := _video_poker_rtp(game, "jacks_or_better", "standard", "mark_holds", "VIDEO-POKER-CHEAT-LOADED", 600)
	if cheat_rtp <= honest_rtp + 0.10:
		failures.append("Video poker holdout did not meaningfully improve return (honest=%.3f cheat=%.3f)." % [honest_rtp, cheat_rtp])


func _check_video_poker_item_luck_alcohol(game: GameModule, failures: Array) -> void:
	var sober: RunState = _vp_fresh(game, "jacks_or_better", "VIDEO-POKER-ALCOHOL", 100000, "standard", 1, 1)
	sober.current_environment["security_profile"] = {"strictness": "tight", "pit_boss": {"enabled": true, "cycle_length": 2, "watched_turns": 1, "cheat_heat_bonus": 20}}
	_xgame_apply_watched_spatial_state(sober, "video_poker", true)
	var sober_deal := game.surface_action_command("video_poker_deal", 0, false, {}, sober, sober.current_environment)
	var sober_ui: Dictionary = _video_poker_holdout_timed_ui(game, sober, sober_deal.get("ui_state", {}), 0)
	var sober_result := game.resolve_with_context("mark_holds", 5, sober, sober.current_environment, sober.create_rng("vp_sober_cheat"), sober_ui)
	var drunk: RunState = _vp_fresh(game, "jacks_or_better", "VIDEO-POKER-ALCOHOL", 100000, "standard", 1, 1)
	drunk.drunk_level = 85
	drunk.current_environment["security_profile"] = sober.current_environment["security_profile"]
	_xgame_apply_watched_spatial_state(drunk, "video_poker", true)
	var drunk_deal := game.surface_action_command("video_poker_deal", 0, false, {}, drunk, drunk.current_environment)
	var drunk_ui: Dictionary = _video_poker_holdout_timed_ui(game, drunk, drunk_deal.get("ui_state", {}), 0)
	var drunk_result := game.resolve_with_context("mark_holds", 5, drunk, drunk.current_environment, drunk.create_rng("vp_sober_cheat"), drunk_ui)
	if int(drunk_result.get("suspicion_delta", 0)) <= int(sober_result.get("suspicion_delta", 0)):
		failures.append("Video poker cheat heat did not respond to alcohol pressure.")
	if int(sober_result.get("suspicion_delta", 0)) < 30:
		failures.append("Video poker cheat heat did not include security/pit-boss watch pressure.")
	var item_run: RunState = _vp_fresh(game, "jacks_or_better", "VIDEO-POKER-ITEM", 100000, "standard", 1, 1)
	item_run.add_item("cheap_sunglasses")
	item_run.current_environment["security_profile"] = sober.current_environment["security_profile"]
	_xgame_apply_watched_spatial_state(item_run, "video_poker", true)
	var item_deal := game.surface_action_command("video_poker_deal", 0, false, {}, item_run, item_run.current_environment)
	var item_ui: Dictionary = _video_poker_holdout_timed_ui(game, item_run, item_deal.get("ui_state", {}), 0)
	var item_result := game.resolve_with_context("mark_holds", 5, item_run, item_run.current_environment, item_run.create_rng("vp_item_cheat"), item_ui)
	if int(item_result.get("suspicion_delta", 0)) >= int(sober_result.get("suspicion_delta", 0)):
		failures.append("Video poker holdout contraband/item hooks did not reduce heat with cheap_sunglasses.")
	var luck_low := _video_poker_rtp_with_luck(game, "VIDEO-POKER-LUCK-LOW", 0)
	var luck_high := _video_poker_rtp_with_luck(game, "VIDEO-POKER-LUCK-HIGH", 10)
	if luck_high <= luck_low:
		failures.append("Video poker returns did not respond to RunState luck (low=%.3f high=%.3f)." % [luck_low, luck_high])


func _video_poker_rtp_with_luck(game: GameModule, seed_text: String, luck: int) -> float:
	var run_state: RunState = _vp_fresh(game, "jacks_or_better", seed_text, 100000000, "standard", 1, 1)
	run_state.baseline_luck = luck
	var rng: RngStream = run_state.create_rng("vp_luck_rate")
	var staked := 0
	var net := 0
	var rounds := 600
	for _round in range(rounds):
		var before := run_state.bankroll
		var result := _video_poker_play_hand(game, run_state, rng, "draw")
		staked += int(result.get("video_poker_bet", 5))
		net += run_state.bankroll - before
	return 1.0 + float(net) / float(staked)


func _check_video_poker_double_up(game: GameModule, failures: Array) -> void:
	# A double-up gamble resolves wins and losses and applies the delta through the host.
	for pick_index in range(4):
		var control_run: RunState = _vp_fresh(game, "jacks_or_better", "VIDEO-POKER-DOUBLE-CONTROL-%d" % pick_index, 1000000)
		var control_environment: Dictionary = control_run.current_environment
		var control_states: Dictionary = control_environment.get("game_states", {})
		var control_machine: Dictionary = control_states.get("video_poker", {})
		control_machine["last_result"] = {"double_credits": 12, "double_chain": 0, "win_credits": 12, "hand": [], "coins": 5}
		control_states["video_poker"] = control_machine
		control_environment["game_states"] = control_states
		control_run.current_environment = control_environment
		var open_command := game.surface_action_command("video_poker_double", 0, false, {}, control_run, control_environment)
		var open_ui: Dictionary = open_command.get("ui_state", {}) if typeof(open_command.get("ui_state", {})) == TYPE_DICTIONARY else {}
		var pick_command := game.surface_action_command("video_poker_double_pick", pick_index, false, open_ui, control_run, control_environment)
		var pick_ui: Dictionary = pick_command.get("ui_state", {}) if typeof(pick_command.get("ui_state", {})) == TYPE_DICTIONARY else {}
		if not bool(pick_command.get("direct_resolve", false)) or int(pick_ui.get("double_pick", -1)) != pick_index:
			failures.append("Video poker double-up pick %d did not resolve from one control press." % (pick_index + 1))
	var result_run: RunState = _vp_fresh(game, "jacks_or_better", "VIDEO-POKER-DOUBLE-RESULT-HOLD", 1000000)
	var result_environment: Dictionary = result_run.current_environment
	var result_states: Dictionary = result_environment.get("game_states", {})
	var result_machine: Dictionary = result_states.get("video_poker", {})
	result_machine["last_result"] = {"double_credits": 12, "double_chain": 0, "win_credits": 12, "hand": [], "coins": 5}
	result_states["video_poker"] = result_machine
	result_environment["game_states"] = result_states
	result_run.current_environment = result_environment
	var result_open: Dictionary = game.surface_action_command("video_poker_double", 0, false, {"surface_time_msec": 1000}, result_run, result_environment)
	var result_open_ui: Dictionary = result_open.get("ui_state", {}) if typeof(result_open.get("ui_state", {})) == TYPE_DICTIONARY else {}
	result_open_ui["surface_time_msec"] = 1200
	var result_pick: Dictionary = game.surface_action_command("video_poker_double_pick", 2, false, result_open_ui, result_run, result_environment)
	var result_pick_ui: Dictionary = result_pick.get("ui_state", {}) if typeof(result_pick.get("ui_state", {})) == TYPE_DICTIONARY else {}
	var resolved: Dictionary = game.resolve_with_context("double_up", 0, result_run, result_environment, result_run.create_rng("vp_double_result_hold"), result_pick_ui)
	var held_surface: Dictionary = game.surface_state(result_run, result_environment, {"surface_time_msec": 1200})
	var held_view: Dictionary = held_surface.get("double_up_view", {}) if typeof(held_surface.get("double_up_view", {})) == TYPE_DICTIONARY else {}
	var held_card: Dictionary = held_view.get("picked_card", {}) if typeof(held_view.get("picked_card", {})) == TYPE_DICTIONARY else {}
	if str(held_surface.get("phase", "")) != "double_result" or not bool(held_surface.get("surface_realtime_state_refresh", false)):
		failures.append("Video poker Double Up did not enter its timed result presentation phase.")
	if int(held_view.get("selected_pick", -1)) != 2 or int(held_card.get("rank", 0)) != int(resolved.get("video_poker_double_pick_rank", -1)):
		failures.append("Video poker Double Up result did not reveal the exact card the player selected.")
	var held_harness := SurfaceHarness.new()
	held_harness.setup(held_surface)
	game.draw_surface(held_harness, held_surface, {"contract_harness": true})
	if not held_harness.labels.has("YOUR PICK") or _surface_harness_has_action(held_harness, "video_poker_double_pick"):
		failures.append("Video poker Double Up result did not showcase and lock the chosen card.")
	var final_hold_surface: Dictionary = game.surface_state(result_run, result_environment, {"surface_time_msec": 2699})
	var returned_surface: Dictionary = game.surface_state(result_run, result_environment, {"surface_time_msec": 2700})
	if str(final_hold_surface.get("phase", "")) != "double_result" or str(returned_surface.get("phase", "")) != "settled":
		failures.append("Video poker Double Up result was not held for exactly 1.5 seconds before returning to the main screen.")
	var det_a: Dictionary = _video_poker_seeded_double_result(game, "VIDEO-POKER-DOUBLE-DETERMINISTIC", 2)
	var det_b: Dictionary = _video_poker_seeded_double_result(game, "VIDEO-POKER-DOUBLE-DETERMINISTIC", 2)
	if JSON.stringify(_video_poker_double_signature(det_a)) != JSON.stringify(_video_poker_double_signature(det_b)):
		failures.append("Video poker double-up did not resolve deterministically for the same seed and pick.")
	var run_state: RunState = _vp_fresh(game, "jacks_or_better", "VIDEO-POKER-DOUBLE", 100000000)
	var environment: Dictionary = run_state.current_environment
	var rng: RngStream = run_state.create_rng("vp_double")
	var rounds := 240
	var wins := 0
	var losses := 0
	var any_delta := false
	for index in range(rounds):
		var state: Dictionary = (environment.get("game_states", {}) as Dictionary).get("video_poker", {})
		state["last_result"] = {"double_credits": 10, "double_chain": 0, "win_credits": 10, "hand": [], "coins": 5}
		var game_states: Dictionary = environment.get("game_states", {})
		game_states["video_poker"] = state
		environment["game_states"] = game_states
		run_state.current_environment = environment
		var ui := {"double_active": true, "double_pick": index % 4}
		var result := game.resolve_with_context("double_up", 0, run_state, environment, rng, ui)
		environment = run_state.current_environment
		var outcome := str(result.get("video_poker_double_outcome", ""))
		if outcome == "win":
			wins += 1
		elif outcome == "lose":
			losses += 1
		if int(result.get("bankroll_delta", 0)) != 0:
			any_delta = true
	if wins <= 0 or losses <= 0:
		failures.append("Video poker double-up did not produce both wins and losses (win=%d lose=%d)." % [wins, losses])
	if not any_delta:
		failures.append("Video poker double-up never moved bankroll.")
	var win_rate := float(wins) / float(rounds)
	if win_rate < 0.4 or win_rate > 0.6:
		failures.append("Video poker double-up win rate %.3f is not a fair gamble." % win_rate)


func _video_poker_seeded_double_result(game: GameModule, seed_text: String, pick_index: int) -> Dictionary:
	var run_state: RunState = _vp_fresh(game, "jacks_or_better", seed_text, 1000000)
	var environment: Dictionary = run_state.current_environment
	var game_states: Dictionary = environment.get("game_states", {})
	var state: Dictionary = game_states.get("video_poker", {})
	state["last_result"] = {"double_credits": 12, "double_chain": 0, "win_credits": 12, "hand": [], "coins": 5}
	game_states["video_poker"] = state
	environment["game_states"] = game_states
	run_state.current_environment = environment
	return game.resolve_with_context("double_up", 0, run_state, environment, run_state.create_rng("vp_double_det"), {"double_active": true, "double_pick": pick_index})


func _video_poker_double_signature(result: Dictionary) -> Dictionary:
	return {
		"ok": bool(result.get("ok", false)),
		"outcome": str(result.get("video_poker_double_outcome", "")),
		"bankroll_delta": int(result.get("bankroll_delta", 0)),
		"next": int(result.get("video_poker_double_next", 0)),
		"at_risk": int(result.get("video_poker_double_at_risk", 0)),
		"message": str(result.get("message", "")),
	}


func _check_video_poker_rtp_bands(game: GameModule, failures: Array) -> void:
	var cabinets := [
		{"variant": "jacks_or_better", "tier": "full_pay", "hands": 1, "seed": "JACKS"},
		{"variant": "deuces_wild", "tier": "full_pay", "hands": 2, "seed": "DEUCES"},
		{"variant": "double_double_bonus", "tier": "full_pay", "hands": 3, "seed": "TRIPLE"},
	]
	for cabinet in cabinets:
		var variant_id := str(cabinet.get("variant", "jacks_or_better"))
		var tier_id := str(cabinet.get("tier", "full_pay"))
		var hand_count := int(cabinet.get("hands", 1))
		var rtp := _video_poker_rtp(game, variant_id, tier_id, "draw", "VIDEO-POKER-RTP-%s" % str(cabinet.get("seed", "CABINET")), 2200, hand_count)
		print("VIDEO_POKER %s/%s/%dHAND RTP = %.4f" % [variant_id, tier_id, hand_count, rtp])
		if rtp < 0.70 or rtp > 1.12:
			failures.append("Video poker active cabinet %s/%s/%d-hand RTP %.4f fell outside the sampled sane band." % [variant_id, tier_id, hand_count, rtp])


func _video_poker_tier_row_mult(game: GameModule, variant_id: String, tier_id: String, row_key: String) -> int:
	var variant: Dictionary = game.call("_variant", {"variant_id": variant_id, "paytable_tier_id": tier_id})
	var rows: Array = variant.get("rows", [])
	for row_value in rows:
		var row: Dictionary = row_value if typeof(row_value) == TYPE_DICTIONARY else {}
		if str(row.get("key", "")) == row_key:
			return int(row.get("mult", 0))
	return 0


func _video_poker_rtp(game: GameModule, variant_id: String, tier_id: String, action_id: String, seed_text: String, rounds: int, hand_count: int = 1) -> float:
	var run_state: RunState = _vp_fresh(game, variant_id, seed_text, 100000000, tier_id, hand_count, 1)
	var environment: Dictionary = run_state.current_environment
	var rng: RngStream = run_state.create_rng("vp_rtp")
	var staked := 0
	var net := 0
	for _round in range(rounds):
		run_state.suspicion = {"level": 0, "cues": [], "local_levels": {}}
		var before := run_state.bankroll
		var result := _video_poker_play_hand(game, run_state, rng, action_id)
		environment = run_state.current_environment
		staked += int(result.get("video_poker_bet", 20))
		net += run_state.bankroll - before
	return 1.0 + float(net) / float(staked)


func _video_poker_play_hand(game: GameModule, run_state: RunState, rng: RngStream, action_id: String) -> Dictionary:
	var environment: Dictionary = run_state.current_environment
	var bet_cmd: Dictionary = game.surface_action_command("video_poker_bet_max", 0, false, {}, run_state, environment)
	var ui: Dictionary = bet_cmd.get("ui_state", {})
	ui["hand_active"] = true
	var state: Dictionary = game.call("_machine_state", run_state, environment)
	var variant: Dictionary = game.call("_variant", state)
	var hand: Array = game.call("_opening_hand", run_state, state)
	ui["holds"] = game.call("_suggested_holds", hand, variant)
	if action_id == "mark_holds":
		ui = _video_poker_holdout_timed_ui(game, run_state, ui, 0)
	return game.resolve_with_context(action_id, 5, run_state, environment, rng, ui)


func _check_pull_tabs_surface_contract(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("PULL-TABS-SURFACE-CONTRACT")
	var environment := _surface_contract_environment()
	var generated_state := game.generate_environment_state(run_state, environment, run_state.create_rng("pull_tab_contract_machine"))
	if generated_state.is_empty():
		failures.append("Pull Tabs did not generate finite deal state for an environment.")
	environment["game_states"] = {"pull_tabs": generated_state}
	var generated_deals: Array = generated_state.get("deals", [])
	var remaining_levels := {}
	for deal_value in generated_deals:
		var generated_deal: Dictionary = deal_value
		var sleeve: Array = generated_deal.get("ticket_sleeve", [])
		if sleeve.is_empty():
			failures.append("Pull Tabs generated deal did not prebuild a fixed ticket sleeve.")
		if int(generated_deal.get("remaining", -1)) != sleeve.size():
			failures.append("Pull Tabs generated deal remaining count did not match sleeve size.")
		if int(generated_deal.get("initial_removed_count", 0)) <= 0:
			failures.append("Pull Tabs generated deal did not remove an unknown opening run of tickets.")
		if int(generated_deal.get("ticket_count", 0)) != 150:
			failures.append("Pull Tabs generated deal did not use the 150-ticket column cap.")
		if (generated_deal.get("prizes", []) as Array).size() < 6:
			failures.append("Pull Tabs generated deal did not expose the full real-style prize ladder.")
		remaining_levels[str(generated_deal.get("remaining", 0))] = true
	if remaining_levels.size() != generated_deals.size():
		failures.append("Pull Tabs generated columns did not start at distinct stack levels.")
	var generated_item_state: Dictionary = generated_state.get("item_state", {})
	var xray_targets: Array = generated_item_state.get("xray_targets", [])
	if xray_targets.size() != mini(2, generated_deals.size()):
		failures.append("Pull Tabs x-ray glasses should preselect two column winner targets.")
	var xray_target_columns := {}
	for target_value in xray_targets:
		if typeof(target_value) != TYPE_DICTIONARY:
			failures.append("Pull Tabs x-ray target was not stored as a dictionary.")
			continue
		var target: Dictionary = target_value
		var deal_index := int(target.get("deal_index", -1))
		if deal_index < 0 or deal_index >= generated_deals.size():
			failures.append("Pull Tabs x-ray target pointed at an invalid column.")
		if int(target.get("payout", 0)) <= 0:
			failures.append("Pull Tabs x-ray target did not identify a winning prize.")
		if bool(target.get("consumed", false)):
			failures.append("Pull Tabs x-ray target should start unconsumed.")
		xray_target_columns[deal_index] = true
	if xray_target_columns.size() != xray_targets.size():
		failures.append("Pull Tabs x-ray glasses should target two distinct columns.")
	_check_pull_tab_deal_variety(game, failures)
	_check_pull_tab_full_deal_integrity(game, failures)
	var environment_before_enter := JSON.stringify(environment)
	var enter_result := game.enter(run_state, environment)
	if not bool(enter_result.get("ok", false)):
		failures.append("Pull Tabs did not enter cleanly.")
	if JSON.stringify(environment) != environment_before_enter:
		failures.append("Pull Tabs entry mutated generated environment state.")
	var surface := game.surface_state(run_state, environment, {})
	if str(surface.get("surface_renderer", "")) != "pull_tab_machine":
		failures.append("Pull Tabs surface did not route to the pull-tab machine renderer.")
	_check_idle_animation_liveness_contract(surface, "Pull Tabs cabinet surface", failures)
	if not bool(surface.get("surface_controls_native", false)):
		failures.append("Pull Tabs surface did not expose native surface controls.")
	if not bool(surface.get("surface_animates_idle", false)):
		failures.append("Pull Tabs cabinet surface must declare idle animation liveness for glow and glare motion.")
	if float(surface.get("surface_web_idle_animation_fps", 0.0)) < 12.0:
		failures.append("Pull Tabs cabinet web idle animation cadence is too low for smooth lights and glass glare.")
	if not bool(surface.get("surface_embeds_outcomes", false)):
		failures.append("Pull Tabs surface did not declare ticket-embedded outcomes.")
	if _surface_blocks_action_while(surface, "pull_tab_buy", "pull_tab_dispense") or _surface_blocks_action_while(surface, "pull_tab_buy_all", "pull_tab_dispense"):
		failures.append("Pull Tabs purchase actions should stay available while dispense animation/audio is active.")
	if not _surface_blocks_action_while(surface, "pull_tab_collect_tray", "pull_tab_dispense"):
		failures.append("Pull Tabs tray collection should still wait for active dispense animation.")
	var deals: Array = surface.get("pull_tab_deals", [])
	if deals.size() != 4:
		failures.append("Pull Tabs surface did not expose four dispenser deal rows.")
	for deal_value in deals:
		var deal: Dictionary = deal_value
		if str(deal.get("form", "")).is_empty() or str(deal.get("serial", "")).is_empty() or (deal.get("prize_rows", []) as Array).is_empty():
			failures.append("Pull Tabs deal flare is missing form, serial, or prize chart data.")
	var peek_harness := SurfaceHarness.new()
	peek_harness.setup(surface)
	game.draw_surface(peek_harness, surface, {"contract_harness": true})
	if not peek_harness.labels.has("PEEK"):
		failures.append("Pull Tabs did not label the no-detector cabinet action as PEEK.")
	for label_value in peek_harness.labels:
		if str(label_value).begins_with("HEAT +"):
			failures.append("Pull Tabs still prints the action's Heat cost on the cabinet button.")
			break
	var buy_all_click := _check_surface_command_non_mutating(game, "pull_tab_buy_all", 0, false, {}, run_state, environment, "pull-tab buy all", failures)
	if str(buy_all_click.get("action_id", "")) != "buy_tab_set" or int(buy_all_click.get("set_stake", 0)) <= 0:
		failures.append("Pull Tabs all-column button did not map to the four-ticket purchase action.")
	var buy_click := _check_surface_command_non_mutating(game, "pull_tab_buy", 0, false, {}, run_state, environment, "pull-tab buy", failures)
	if str(buy_click.get("action_kind", "")) != "legal" or str(buy_click.get("action_id", "")) != "buy_tab":
		failures.append("Pull Tabs buy button did not map to the legal ticket purchase action.")
	if not bool(buy_click.get("direct_resolve", false)) or not bool(buy_click.get("resolve", false)):
		failures.append("Pull Tabs buy button should purchase on the first click without requiring confirm.")
	var scan_click := _check_surface_command_non_mutating(game, "pull_tab_detector_scan", 0, false, {}, run_state, environment, "pull-tab peek", failures)
	if str(scan_click.get("action_kind", "")) != "cheat" or str(scan_click.get("action_id", "")) != "tab_detector_scan":
		failures.append("Pull Tabs PEEK button did not map to the shared peek/scan action.")
	if bool(scan_click.get("direct_resolve", false)) or bool(scan_click.get("resolve", false)):
		failures.append("Pull Tabs PEEK button bypassed risky-action arm/confirm semantics.")
	if not bool(scan_click.get("skip_stake_validation", false)):
		failures.append("Pull Tabs detector scan incorrectly requires a ticket stake.")
	var machine_for_buy: Dictionary = (environment.get("game_states", {}) as Dictionary).get("pull_tabs", {})
	var deals_before_buy: Array = machine_for_buy.get("deals", [])
	var first_deal_before: Dictionary = deals_before_buy[0] if not deals_before_buy.is_empty() else {}
	var first_sleeve_before: Array = first_deal_before.get("ticket_sleeve", [])
	var expected_first_payout := _pull_tab_sleeve_entry_payout(first_deal_before, int(first_sleeve_before[0]) if not first_sleeve_before.is_empty() else -1)
	var machine_before := JSON.stringify(environment.get("game_states", {}))
	var before := _run_state_result_snapshot(run_state)
	var result := game.resolve_with_context("buy_tab", int(buy_click.get("set_stake", 1)), run_state, environment, run_state.create_rng("pull_tab_buy"), buy_click.get("ui_state", {}))
	_check_action_result_shape(result, "legal", failures)
	_check_action_result_applied(before, run_state, result, "pull-tab buy result", failures)
	_check_pull_tab_result_details(result, failures)
	if int(result.get("pull_tab_payout", -1)) != expected_first_payout:
		failures.append("Pull Tabs buy did not dispense the next predefined sleeve outcome.")
	if not bool(result.get("suppress_music_outcome", false)):
		failures.append("Pull Tabs purchase exposed its hidden outcome to the win/loss music system.")
	if JSON.stringify(environment.get("game_states", {})) == machine_before:
		failures.append("Pull Tabs buy did not update persistent finite deal state.")
	var machine_after_buy: Dictionary = (environment.get("game_states", {}) as Dictionary).get("pull_tabs", {})
	var deals_after_buy: Array = machine_after_buy.get("deals", [])
	var first_deal_after: Dictionary = deals_after_buy[0] if not deals_after_buy.is_empty() else {}
	if not first_sleeve_before.is_empty() and (first_deal_after.get("ticket_sleeve", []) as Array).size() != maxi(0, first_sleeve_before.size() - 1):
		failures.append("Pull Tabs buy did not consume exactly one ticket from the fixed sleeve.")
	var tray_surface := game.surface_state(run_state, environment, {})
	if int(tray_surface.get("pull_tab_tray_count", 0)) <= 0 or (tray_surface.get("pull_tab_tray_stack", []) as Array).is_empty():
		failures.append("Pull Tabs surface did not leave the dispensed ticket in the machine tray.")
	if int(tray_surface.get("pull_tab_stack_count", 0)) != 0:
		failures.append("Pull Tabs buy moved a ticket directly into the play pile instead of the tray.")
	if not bool(tray_surface.get("surface_animates_idle", false)):
		failures.append("Pull Tabs tray surface lost cabinet idle animation liveness after a ticket purchase.")
	var dispense_events: Array = tray_surface.get("pull_tab_dispense_events", []) as Array
	if dispense_events.is_empty():
		failures.append("Pull Tabs buy did not expose tray-drop dispense animation events.")
	else:
		var first_event: Dictionary = dispense_events[0] as Dictionary
		var animation_ticket_value: Variant = first_event.get("ticket", {})
		var animation_ticket: Dictionary = animation_ticket_value as Dictionary if typeof(animation_ticket_value) == TYPE_DICTIONARY else {}
		if animation_ticket.has("rows") or animation_ticket.has("prize_rows") or animation_ticket.has("payout"):
			failures.append("Pull Tabs dispense animation event carried full ticket outcome payload.")
	if str(tray_surface.get("pull_tab_last_ticket_id", "")).is_empty() or not tray_surface.has("pull_tab_stack_cursor"):
		failures.append("Pull Tabs surface did not expose dispenser animation and stack cursor state.")
	_check_pull_tab_late_run_animation_clock(tray_surface, failures)
	var collect_click := game.surface_action_command("pull_tab_collect_tray", 0, false, {}, run_state, environment)
	if not bool(collect_click.get("handled", false)) or not bool(collect_click.get("environment_changed", false)):
		failures.append("Pull Tabs tray click did not collect tray tickets into the play pile.")
	var stack_surface := game.surface_state(run_state, environment, collect_click.get("ui_state", {}))
	if int(stack_surface.get("pull_tab_stack_count", 0)) <= 0 or (stack_surface.get("pull_tab_stack", []) as Array).is_empty() or int(stack_surface.get("pull_tab_tray_count", 0)) != 0:
		failures.append("Pull Tabs tray collection did not expose the collected ticket stack.")
	var control_harness := SurfaceHarness.new()
	control_harness.setup(stack_surface)
	game.draw_surface(control_harness, stack_surface, {})
	var empty_harness := SurfaceHarness.new()
	empty_harness.setup(surface)
	game.draw_surface(empty_harness, surface, {})
	if not empty_harness.labels.has("0/0"):
		failures.append("Pull Tabs empty ticket pile displayed a phantom current ticket.")
	var open_button_rect := Rect2()
	var auto_open_button_rect := Rect2()
	var found_open_button := false
	var found_auto_open_button := false
	for hit_value in control_harness.hit_regions:
		if typeof(hit_value) != TYPE_DICTIONARY:
			continue
		var hit: Dictionary = hit_value
		if str(hit.get("action", "")) == "pull_tab_next_unopened":
			open_button_rect = hit.get("rect", Rect2()) as Rect2
			found_open_button = true
		elif str(hit.get("action", "")) == "pull_tab_auto_open":
			auto_open_button_rect = hit.get("rect", Rect2()) as Rect2
			found_auto_open_button = true
	if not found_auto_open_button or not control_harness.labels.has("AUTO OPEN"):
		failures.append("Pull Tabs right panel did not draw an Auto Open button for a purchased ticket stack.")
	elif not found_open_button or auto_open_button_rect.position.x <= open_button_rect.end.x or absf(auto_open_button_rect.position.y - open_button_rect.position.y) > 0.1:
		failures.append("Pull Tabs Auto Open button was not positioned beside Open on the right panel.")
	var header_button_rects_value: Variant = game.call("_pull_tab_stack_header_button_rects", Rect2(430, 18, 448, 394))
	var header_button_rects: Array = header_button_rects_value if typeof(header_button_rects_value) == TYPE_ARRAY else []
	var pile_label_reservation := Rect2(440, 20, 190, 30)
	var native_leave_rect := Rect2(776, 22, 86, 34)
	if header_button_rects.size() != 4:
		failures.append("Pull Tabs header layout did not provide <, >, Open, and Auto Open control rectangles.")
	else:
		for button_index in range(header_button_rects.size()):
			var button_rect_value: Variant = header_button_rects[button_index]
			var button_rect: Rect2 = button_rect_value as Rect2
			if button_rect.intersects(pile_label_reservation):
				failures.append("Pull Tabs header controls overlap the ticket-pile X/X label reservation.")
				break
			if button_rect.intersects(native_leave_rect):
				failures.append("Pull Tabs header controls overlap the native Leave button.")
				break
			if button_index == 3 and button_rect.size.x > 50.0:
				failures.append("Pull Tabs Auto Open button exceeded its compact header width.")
				break
	var second_buy_click := _check_surface_command_non_mutating(game, "pull_tab_buy", 1, false, {}, run_state, environment, "second pull-tab buy", failures)
	if str(second_buy_click.get("action_id", "")) == "buy_tab":
		game.resolve_with_context("buy_tab", int(second_buy_click.get("set_stake", 1)), run_state, environment, run_state.create_rng("pull_tab_second_buy"), second_buy_click.get("ui_state", {}))
		game.surface_action_command("pull_tab_collect_tray", 0, false, {}, run_state, environment)
	var auto_start_msec := 12000
	var auto_toggle_state := {"surface_time_msec": auto_start_msec, "drunk_scaled_surface_time_msec": auto_start_msec}
	var auto_toggle := _check_surface_command_non_mutating(game, "pull_tab_auto_open", 0, false, auto_toggle_state, run_state, environment, "pull-tab auto open toggle", failures)
	var auto_state: Dictionary = auto_toggle.get("ui_state", {}) if typeof(auto_toggle.get("ui_state", {})) == TYPE_DICTIONARY else {}
	var auto_due_msec := int(auto_state.get("pull_tab_auto_open_next_msec", 0))
	if not bool(auto_state.get("pull_tab_auto_open_active", false)) or auto_due_msec <= auto_start_msec:
		failures.append("Pull Tabs Auto Open did not activate and schedule its first simulated click.")
	if game.surface_needs_auto_tick(auto_state, run_state, environment):
		failures.append("Pull Tabs Auto Open requested work before its first scheduled click.")
	var auto_tick_keys := game.surface_auto_tick_state_keys()
	if not auto_tick_keys.has("pull_tab_auto_open_active") or not auto_tick_keys.has("pull_tab_auto_open_next_msec") or auto_tick_keys.has("pull_tab_reveals"):
		failures.append("Pull Tabs Auto Open per-frame gate did not keep its state-key view minimal.")
	var auto_due_state := auto_state.duplicate(true)
	auto_due_state["surface_time_msec"] = auto_due_msec
	auto_due_state["drunk_scaled_surface_time_msec"] = auto_due_msec
	if not game.surface_needs_auto_tick(auto_due_state, run_state, environment):
		failures.append("Pull Tabs Auto Open did not request its scheduled reveal click.")
	var auto_reveal := game.surface_auto_action_command(auto_due_state, run_state, environment, {})
	var auto_reveal_state: Dictionary = auto_reveal.get("ui_state", {}) if typeof(auto_reveal.get("ui_state", {})) == TYPE_DICTIONARY else {}
	var auto_reveal_surface := game.surface_state(run_state, environment, auto_reveal_state)
	var auto_reveal_stack: Array = auto_reveal_surface.get("pull_tab_stack", []) if typeof(auto_reveal_surface.get("pull_tab_stack", [])) == TYPE_ARRAY else []
	if not bool(auto_reveal.get("handled", false)) or auto_reveal_stack.is_empty() or not bool((auto_reveal_stack[0] as Dictionary).get("fully_revealed", false)):
		failures.append("Pull Tabs Auto Open did not route its first tick through the normal ticket reveal path.")
	elif str(auto_reveal.get("surface_audio_cue", "")) != ("ticket_win" if int((auto_reveal_stack[0] as Dictionary).get("payout", 0)) > 0 else "ticket_peel") or str(auto_reveal.get("surface_audio_action", "")) != "pull_tab_reveal_next":
		failures.append("Pull Tabs Auto Open did not time its win/peel cue to the reveal tick.")
	var auto_file_due_msec := int(auto_reveal_state.get("pull_tab_auto_open_next_msec", 0))
	var auto_file_state := auto_reveal_state.duplicate(true)
	auto_file_state["surface_time_msec"] = auto_file_due_msec
	auto_file_state["drunk_scaled_surface_time_msec"] = auto_file_due_msec
	var auto_file := game.surface_auto_action_command(auto_file_state, run_state, environment, {})
	if str(auto_file.get("action_id", "")) != "sort_tab_ticket" or not bool(auto_file.get("direct_resolve", false)):
		failures.append("Pull Tabs Auto Open did not route its next tick through the normal ticket filing path.")
	if str(auto_file.get("surface_audio_cue", "")) != "ticket_navigation" or str(auto_file.get("surface_audio_action", "")) != "pull_tab_file_ticket":
		failures.append("Pull Tabs Auto Open file tick did not request the normal filing/navigation SFX cue.")
	var auto_off := game.surface_action_command("pull_tab_auto_open", 0, false, auto_file.get("ui_state", {}), run_state, environment)
	var auto_off_state: Dictionary = auto_off.get("ui_state", {}) if typeof(auto_off.get("ui_state", {})) == TYPE_DICTIONARY else {}
	if bool(auto_off_state.get("pull_tab_auto_open_active", true)) or int(auto_off_state.get("pull_tab_auto_open_next_msec", -1)) != 0:
		failures.append("Pull Tabs Stop Auto did not cancel the repeating click schedule.")
	var next_ticket_click := _check_surface_command_non_mutating(game, "pull_tab_next", 0, false, {}, run_state, environment, "pull-tab next ticket", failures)
	var next_ticket_state: Dictionary = next_ticket_click.get("ui_state", {})
	if int(next_ticket_state.get("pull_tab_stack_cursor", 0)) != mini(1, int(game.surface_state(run_state, environment, {}).get("pull_tab_stack_count", 1)) - 1):
		failures.append("Pull Tabs next-ticket navigation did not update UI-local stack cursor.")
	var reveal_state := {}
	var reveal_click := _check_surface_command_non_mutating(game, "pull_tab_reveal_next", 0, false, reveal_state, run_state, environment, "pull-tab reveal", failures)
	reveal_state = reveal_click.get("ui_state", {})
	var revealed_surface := game.surface_state(run_state, environment, reveal_state)
	var revealed_stack: Array = revealed_surface.get("pull_tab_stack", [])
	if revealed_stack.is_empty() or not bool((revealed_stack[0] as Dictionary).get("fully_revealed", false)):
		failures.append("Pull Tabs reveal command did not open all ticket rows from one click as UI-local state.")
	elif int((revealed_stack[0] as Dictionary).get("payout", 0)) > 0 and str(reveal_click.get("surface_audio_cue", "")) != "ticket_win":
		failures.append("Pull Tabs winning-ticket sound did not wait for the peel action.")
	var compacted_target_machine := {
		"deals": [{"id": "a"}, {"id": "b"}, {"id": "c"}],
		"item_state": {"xray_targets": [{"consumed": true, "deal_index": 2, "ticket_number": 11}]},
	}
	var compacted_target_ticket := {"deal_index": 2, "ticket_number_value": 11}
	if not bool(game.call("_ticket_is_consumed_xray_target", compacted_target_machine, compacted_target_ticket)):
		failures.append("Pull Tabs coach identity lost a consumed X-ray target when the compacted ticket omitted its convenience flag.")
	if str(reveal_click.get("action_id", "")) != "":
		failures.append("Pull Tabs reveal click should not immediately sort the ticket.")
	if str(revealed_surface.get("pull_tab_reveal_animation_id", "")).is_empty():
		failures.append("Pull Tabs reveal click did not expose a row-by-row peel animation.")
	if (revealed_surface.get("pull_tab_winner_pile", []) as Array).is_empty() == false or (revealed_surface.get("pull_tab_loser_pile", []) as Array).is_empty() == false:
		failures.append("Pull Tabs reveal moved a ticket into a pile before the file click.")
	var revealed_harness := SurfaceHarness.new()
	revealed_harness.setup(revealed_surface)
	game.draw_surface(revealed_harness, revealed_surface, {})
	var revealed_file_rect := Rect2()
	for hit_value in revealed_harness.hit_regions:
		if typeof(hit_value) != TYPE_DICTIONARY:
			continue
		var hit: Dictionary = hit_value
		match str(hit.get("action", "")):
			"pull_tab_file_ticket":
				revealed_file_rect = hit.get("rect", Rect2()) as Rect2
	if revealed_file_rect.size.x < 300.0 or revealed_file_rect.size.y < 160.0:
		failures.append("Pull Tabs fully revealed ticket itself was not the click-to-file target.")
	if revealed_harness.labels.has("FILE"):
		failures.append("Pull Tabs retained the separate File button after moving filing onto the completed ticket.")
	var file_click := _check_surface_command_non_mutating(game, "pull_tab_file_ticket", 0, false, reveal_state, run_state, environment, "pull-tab file ticket", failures)
	if str(file_click.get("action_id", "")) != "sort_tab_ticket" or not bool(file_click.get("direct_resolve", false)):
		failures.append("Pull Tabs file click did not request a direct ticket-sort resolution.")
	if not bool(file_click.get("preserve_surface_ui_state", false)):
		failures.append("Pull Tabs file click should preserve UI-local animation state.")
	var file_state: Dictionary = file_click.get("ui_state", {})
	var file_surface := game.surface_state(run_state, environment, file_state)
	if str(file_surface.get("pull_tab_file_animation_id", "")).is_empty() or (file_surface.get("pull_tab_file_animation_ticket", {}) as Dictionary).is_empty():
		failures.append("Pull Tabs file click did not expose placement animation state.")
	var sort_before := _run_state_result_snapshot(run_state)
	var sort_result := game.resolve_with_context("sort_tab_ticket", 0, run_state, environment, run_state.create_rng("pull_tab_sort"), file_state)
	_check_action_result_shape(sort_result, "legal", failures)
	_check_action_result_applied(sort_before, run_state, sort_result, "pull-tab sort result", failures)
	_check_pull_tab_result_details(sort_result, failures)
	if int(sort_result.get("bankroll_delta", 0)) != 0:
		failures.append("Pull Tabs sorting an opened ticket should not pay bankroll immediately.")
	if not bool(sort_result.get("suppress_music_outcome", false)):
		failures.append("Pull Tabs filing replayed the winning-ticket sound after reveal.")
	var sorted_surface := game.surface_state(run_state, environment, file_state)
	if (sorted_surface.get("pull_tab_winner_pile", []) as Array).is_empty() and (sorted_surface.get("pull_tab_loser_pile", []) as Array).is_empty():
		failures.append("Pull Tabs did not move a fully opened ticket into a winner or loser pile.")
	var hooks := game.environment_interactable_objects(run_state, environment)
	if hooks.is_empty():
		failures.append("Pull Tabs did not expose a room-side redemption clerk.")
	else:
		var cash_in_found := false
		for hook_value in hooks:
			if typeof(hook_value) != TYPE_DICTIONARY:
				continue
			for action_value in (hook_value as Dictionary).get("available_actions", []):
				if typeof(action_value) == TYPE_DICTIONARY and str((action_value as Dictionary).get("id", "")) == "redeem_pull_tab_winners" and str((action_value as Dictionary).get("label", "")) == "Cash In":
					cash_in_found = true
		if not cash_in_found:
			failures.append("Pull Tabs redemption control did not use the Cash In label.")
	var winner_count_harness := SurfaceHarness.new()
	winner_count_harness.setup(sorted_surface)
	game.call("_draw_pull_tab_ordered_winner_pile", winner_count_harness, Rect2(0, 0, 150, 100), [_pull_tab_test_ticket_result("one", 5), _pull_tab_test_ticket_result("two", 5)])
	if not winner_count_harness.labels.has("WINNERS x2"):
		failures.append("Pull Tabs winners pile did not draw its winner count.")
	_clear_pull_tab_winners(environment)
	_set_pull_tab_loser_count(environment, 3)
	_inject_pull_tab_winner(environment, _pull_tab_test_ticket_result("clean", 5))
	run_state.capture_portable_ticket_piles_from_environment(environment)
	var redeem_before := _run_state_result_snapshot(run_state)
	var redeem_command := game.environment_action_command("ticket_redeemer", "redeem_pull_tab_winners", run_state, environment, run_state.create_rng("pull_tab_redeem"))
	if not bool(redeem_command.get("handled", false)):
		failures.append("Pull Tabs redemption clerk did not handle winner redemption.")
	var redeem_result: Dictionary = redeem_command.get("result", {})
	if str(redeem_result.get("type", "")) != "game_hook" or int(redeem_result.get("bankroll_delta", 0)) <= 0:
		failures.append("Pull Tabs redemption did not return a cashout game_hook result.")
	else:
		if int(redeem_result.get("suspicion_delta", 0)) != 0:
			failures.append("Pull Tabs legitimate redemption added heat without a suspicious ticket trail.")
		GameModule.apply_result(run_state, redeem_result, run_state.create_rng("pull_tab_redeem_apply"))
		_check_action_result_applied(redeem_before, run_state, redeem_result, "pull-tab redemption result", failures)
	var redeemed_surface := game.surface_state(run_state, environment, reveal_state)
	if int(redeemed_surface.get("pull_tab_pending_payout", 0)) != 0:
		failures.append("Pull Tabs redemption did not clear pending winner payout.")
	_set_pull_tab_loser_count(environment, 0)
	for high_ticket_index in range(2):
		_inject_pull_tab_winner(environment, _pull_tab_test_ticket_result("high:%d" % high_ticket_index, 40))
	run_state.capture_portable_ticket_piles_from_environment(environment)
	var pattern_redeem_before := _run_state_result_snapshot(run_state)
	var pattern_redeem_command := game.environment_action_command("ticket_redeemer", "redeem_pull_tab_winners", run_state, environment, run_state.create_rng("pull_tab_pattern_redeem"))
	var pattern_redeem_result: Dictionary = pattern_redeem_command.get("result", {})
	if not bool(pattern_redeem_command.get("handled", false)):
		failures.append("Pull Tabs suspicious cashout pattern was not handled by the redemption clerk.")
	elif int(pattern_redeem_result.get("suspicion_delta", 0)) <= 0:
		failures.append("Pull Tabs repeated high-value winners with no loser trail did not add cashier heat.")
	elif int(pattern_redeem_result.get("pull_tab_cashout_pattern_heat", 0)) <= 0:
		failures.append("Pull Tabs suspicious cashout did not report pattern heat.")
	elif int(pattern_redeem_result.get("pull_tab_loser_trail_count", -1)) != 0:
		failures.append("Pull Tabs suspicious cashout did not report the visible loser trail count.")
	else:
		GameModule.apply_result(run_state, pattern_redeem_result, run_state.create_rng("pull_tab_pattern_redeem_apply"))
		_check_action_result_applied(pattern_redeem_before, run_state, pattern_redeem_result, "pull-tab suspicious redemption result", failures)
	_check_pull_tab_tarot_reading_surface(game, failures)
	_check_pull_tab_item_cheat_exemption(game, failures)
	run_state.set_environment(environment)
	var restored: RunState = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	var restored_game_states: Dictionary = restored.current_environment.get("game_states", {})
	if not restored_game_states.has("pull_tabs"):
		failures.append("Pull Tabs generated deal state did not round-trip through RunState serialization.")
	_check_pull_tab_receipt_compaction(game, failures)
	_check_pull_tab_portable_inventory(game, failures)


func _check_pull_tab_late_run_animation_clock(surface: Dictionary, failures: Array) -> void:
	var channels: Array = surface.get("surface_animation_channels", []) if typeof(surface.get("surface_animation_channels", [])) == TYPE_ARRAY else []
	var dispense_channel: Dictionary = {}
	for channel_value in channels:
		if typeof(channel_value) == TYPE_DICTIONARY and str((channel_value as Dictionary).get("id", "")) == "pull_tab_dispense":
			dispense_channel = channel_value as Dictionary
			break
	if dispense_channel.is_empty() or str(dispense_channel.get("clock_source", "")) != "presentation":
		failures.append("Pull Tabs dispense animation is not bound to the live presentation clock.")
		return
	var skewed_start := 250000
	var skewed_surface := surface.duplicate(true)
	skewed_surface["surface_time_msec"] = 5000
	skewed_surface["surface_presentation_time_msec"] = skewed_start + 120
	var skewed_channels: Array = skewed_surface.get("surface_animation_channels", [])
	for channel_index in range(skewed_channels.size()):
		if typeof(skewed_channels[channel_index]) != TYPE_DICTIONARY:
			continue
		var channel: Dictionary = (skewed_channels[channel_index] as Dictionary).duplicate(true)
		if str(channel.get("id", "")) != "pull_tab_dispense":
			continue
		channel["active_id"] = "late-run-dispense"
		channel["active"] = true
		channel["started_msec"] = skewed_start
		channel["duration_msec"] = 760
		skewed_channels[channel_index] = channel
	skewed_surface["surface_animation_channels"] = skewed_channels
	var canvas: Control = GameSurfaceCanvasScript.new()
	canvas.size = Vector2(ArtContractsScript.GAME_BOARD_SIZE)
	canvas.render_game_snapshot(skewed_surface)
	var elapsed_msec := int(round(canvas.surface_elapsed("pull_tab_dispense") * 1000.0))
	if elapsed_msec < 100 or elapsed_msec > 160 or not canvas.surface_animation_active("pull_tab_dispense"):
		failures.append("Pull Tabs late-run dispense animation used engine uptime instead of its surface clock: %dms." % elapsed_msec)
	canvas.apply_surface_state_patch({"surface_time_msec": 5000, "surface_presentation_time_msec": skewed_start + 320})
	var advanced_msec := int(round(canvas.surface_elapsed("pull_tab_dispense") * 1000.0))
	if advanced_msec < 290 or advanced_msec > 350:
		failures.append("Pull Tabs dispense animation did not advance smoothly on the surface clock: %dms." % advanced_msec)
	canvas.free()


func _check_pull_tab_receipt_compaction(game: GameModule, failures: Array) -> void:
	var losers: Array = []
	for index in range(64):
		losers.append({
			"id": "settled-loser-%d" % index,
			"ticket_number": "L-%d" % index,
			"display_name": "Filed Pull Tab",
			"palette": {"paper": "#fff0d8", "accent": "#ff4fb3", "ink": "#241027"},
			"price": 1,
			"payout": 0,
			"rows": [["BAR", "LEMON", "BELL"]],
			"prize_rows": [{"label": "Jackpot", "symbols": ["BAR", "BAR", "BAR"], "payout": 1000}],
		})
	var winners := [
		{"id": "settled-winner-a", "ticket_number": "W-A", "display_name": "Winner", "price": 1, "payout": 25, "rows": [["BAR", "BAR", "BAR"]], "prize_rows": [{"payout": 25}]},
		{"id": "settled-winner-b", "ticket_number": "W-B", "display_name": "Winner", "price": 2, "payout": 50, "rows": [["BAR", "BAR", "BAR"]], "prize_rows": [{"payout": 50}]},
	]
	var compacted := RunState.compact_portable_ticket_state("pull_tabs", {"winner_pile": winners, "loser_pile": losers}, true)
	var retained_losers: Array = compacted.get("loser_pile", [])
	var retained_winners: Array = compacted.get("winner_pile", [])
	if retained_losers.size() != RunState.PORTABLE_PULL_TAB_LOSER_RECEIPT_LIMIT or int(compacted.get("loser_archive_count", 0)) != 64 - RunState.PORTABLE_PULL_TAB_LOSER_RECEIPT_LIMIT:
		failures.append("Pull Tabs did not bound settled loser receipts while preserving the exact historical count.")
	elif (retained_losers[0] as Dictionary).has("rows") or (retained_losers[0] as Dictionary).has("prize_rows"):
		failures.append("Pull Tabs retained resolved rows and prize charts in a filed loser receipt.")
	if retained_winners.size() != 2 or int((retained_winners[0] as Dictionary).get("payout", 0)) + int((retained_winners[1] as Dictionary).get("payout", 0)) != 75:
		failures.append("Pull Tabs compaction lost an unpaid winner or changed its payout.")
	elif (retained_winners[0] as Dictionary).has("rows") or (retained_winners[0] as Dictionary).has("prize_rows"):
		failures.append("Pull Tabs retained resolved playfield data in an unpaid winner receipt.")
	var tutorial_receipt := RunState.compact_portable_ticket_state("pull_tabs", {"winner_pile": [{"id": "tutorial-winner", "deal_index": 2, "ticket_number_value": 11, "xray_target_consumed": true, "payout": 25}]}, true)
	var tutorial_winners: Array = tutorial_receipt.get("winner_pile", [])
	if tutorial_winners.is_empty() or int((tutorial_winners[0] as Dictionary).get("deal_index", -1)) != 2 or int((tutorial_winners[0] as Dictionary).get("ticket_number_value", -1)) != 11 or not bool((tutorial_winners[0] as Dictionary).get("xray_target_consumed", false)):
		failures.append("Pull Tabs receipt compaction removed the scalar identity needed by tutorial winner progression.")
	var count_harness := SurfaceHarness.new()
	game.call("_draw_pull_tab_messy_loser_pile", count_harness, Rect2(0, 0, 150, 100), retained_losers, "", false, 64)
	if not count_harness.labels.has("64"):
		failures.append("Pull Tabs compact loser pile did not draw the full archived-plus-visible count.")


func _check_pull_tab_portable_inventory(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("PULL-TABS-PORTABLE-INVENTORY")
	run_state.bankroll = 500
	var origin := {
		"id": "portable_jazz_a",
		"world_node_id": "jazz-node-a",
		"display_name": "Blue Note Jazz Club",
		"archetype_id": "jazz_club",
		"kind": "bar",
		"game_ids": ["pull_tabs"],
		"game_states": {},
		"economic_profile": {"stake_floor": 1, "stake_ceiling": 20},
		"visual_context": {"scene_type": "jazz_club"},
	}
	origin["game_states"] = {"pull_tabs": game.generate_environment_state(run_state, origin, run_state.create_rng("portable-tabs-stock-a"))}
	run_state.current_environment = origin
	var buy := game.surface_action_command("pull_tab_buy", 0, false, {}, run_state, run_state.current_environment)
	game.resolve_with_context("buy_tab", int(buy.get("set_stake", 1)), run_state, run_state.current_environment, run_state.create_rng("portable-tabs-buy-a"), buy.get("ui_state", {}))
	game.surface_action_command("pull_tab_collect_tray", 0, false, {}, run_state, run_state.current_environment)
	if not run_state.inventory.has(RunState.PULL_TAB_PILE_ITEM_ID):
		failures.append("Pull Tabs purchase did not add the Pile of Pull Tabs inventory item.")
	var reveal := game.surface_action_command("pull_tab_reveal_next", 0, false, {}, run_state, run_state.current_environment)
	var reveal_state: Dictionary = reveal.get("ui_state", {})
	game.checkpoint_surface_ui_state(reveal_state, run_state, run_state.current_environment)
	var stored_stack: Array = run_state.portable_ticket_state("pull_tabs", run_state.current_environment).get("ticket_stack", [])
	if stored_stack.is_empty() or not bool((stored_stack[0] as Dictionary).get("fully_revealed", false)):
		failures.append("Pull Tabs did not checkpoint its opened-window state into the inventory pile when leaving the surface.")
	elif str((stored_stack[0] as Dictionary).get("origin_key", "")) != RunState.portable_ticket_origin_key(run_state.current_environment):
		failures.append("Pull Tabs portable record did not stamp its purchase origin on the ticket.")
	var origin_return := run_state.current_environment.duplicate(true)
	var elsewhere := {
		"id": "portable_jazz_b",
		"world_node_id": "jazz-node-b",
		"display_name": "Second Jazz Club",
		"archetype_id": "jazz_club",
		"kind": "bar",
		"game_ids": ["pull_tabs"],
		"game_states": {},
		"economic_profile": {"stake_floor": 1, "stake_ceiling": 20},
		"visual_context": {"scene_type": "jazz_club"},
	}
	elsewhere["game_states"] = {"pull_tabs": game.generate_environment_state(run_state, elsewhere, run_state.create_rng("portable-tabs-stock-b"))}
	run_state.set_environment(elsewhere)
	var elsewhere_surface := game.surface_state(run_state, run_state.current_environment, {})
	if int(elsewhere_surface.get("pull_tab_stack_count", 0)) != 0 or int(elsewhere_surface.get("pull_tab_tray_count", 0)) != 0:
		failures.append("Pull Tabs exposed another location's owned tickets on the wrong machine.")
	var loaded: RunState = RunStateScript.new()
	loaded.from_dict(run_state.to_dict())
	loaded.set_environment(origin_return)
	var returned_surface := game.surface_state(loaded, loaded.current_environment, {})
	var returned_stack: Array = returned_surface.get("pull_tab_stack", [])
	if returned_stack.is_empty() or not bool((returned_stack[0] as Dictionary).get("fully_revealed", false)):
		failures.append("Pull Tabs did not save/load and restore the exact opened-window state at its purchase location.")
	var portable := loaded.portable_ticket_state("pull_tabs", loaded.current_environment).duplicate(true)
	var forced_winner := {
		"id": "portable-tab-winner",
		"display_name": "Portable Pull-Tab",
		"ticket_number": "P-100",
		"price": 1,
		"payout": 25,
		"rows": [["BAR", "BAR", "BAR"]],
		"revealed_count": 1,
		"fully_revealed": true,
		"sorted": true,
		"origin_key": RunState.portable_ticket_origin_key(loaded.current_environment),
		"origin_name": RunState.portable_ticket_origin_name(loaded.current_environment),
	}
	portable["winner_pile"] = [forced_winner]
	loaded.remember_portable_ticket_state("pull_tabs", loaded.current_environment, portable)
	game.surface_state(loaded, loaded.current_environment, {})
	origin_return = loaded.current_environment.duplicate(true)
	# The portable registry is newer than this deliberately stale live machine.
	# Departure must not capture the stale machine back over the action-authored
	# winner; this is the navigation seam that passive previews exposed.
	var stale_game_states: Dictionary = origin_return.get("game_states", {}) if typeof(origin_return.get("game_states", {})) == TYPE_DICTIONARY else {}
	var stale_machine: Dictionary = stale_game_states.get("pull_tabs", {}) if typeof(stale_game_states.get("pull_tabs", {})) == TYPE_DICTIONARY else {}
	var stale_winners: Array = stale_machine.get("winner_pile", []) if typeof(stale_machine.get("winner_pile", [])) == TYPE_ARRAY else []
	var stale_has_forced_winner := false
	for stale_winner_value in stale_winners:
		if typeof(stale_winner_value) == TYPE_DICTIONARY and str((stale_winner_value as Dictionary).get("id", "")) == "portable-tab-winner":
			stale_has_forced_winner = true
	if stale_has_forced_winner:
		failures.append("Pull Tabs stale-machine travel fixture unexpectedly synchronized the newer portable winner before departure.")
	loaded.set_environment(elsewhere)
	var retained_portable := loaded.portable_ticket_state("pull_tabs", origin_return)
	var retained_winners: Array = retained_portable.get("winner_pile", []) if typeof(retained_portable.get("winner_pile", [])) == TYPE_ARRAY else []
	var retained_forced_winner := false
	for retained_winner_value in retained_winners:
		if typeof(retained_winner_value) == TYPE_DICTIONARY and str((retained_winner_value as Dictionary).get("id", "")) == "portable-tab-winner":
			retained_forced_winner = true
	if not retained_forced_winner:
		failures.append("Travel overwrote a newer portable Pull Tabs winner with stale environment machine state.")
	var wrong_cash_before := loaded.bankroll
	var wrong_cash: Dictionary = game.environment_action_command("ticket_redeemer", "redeem_pull_tab_winners", loaded, loaded.current_environment, loaded.create_rng("portable-tabs-wrong-clerk")).get("result", {})
	if int(wrong_cash.get("bankroll_delta", 0)) != 0 or loaded.bankroll != wrong_cash_before:
		failures.append("Pull Tabs allowed a winning ticket to be redeemed away from its purchase location.")
	loaded.set_environment(origin_return)
	var origin_cash_before := loaded.bankroll
	var origin_cash: Dictionary = game.environment_action_command("ticket_redeemer", "redeem_pull_tab_winners", loaded, loaded.current_environment, loaded.create_rng("portable-tabs-origin-clerk")).get("result", {})
	GameModule.apply_result(loaded, origin_cash, loaded.create_rng("portable-tabs-origin-apply"))
	if int(origin_cash.get("bankroll_delta", 0)) != 25 or loaded.bankroll != origin_cash_before + 25:
		failures.append("Pull Tabs purchase-location clerk did not redeem a returned winning ticket.")


func _check_pull_tab_item_cheat_exemption(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("PULL-TABS-ITEM-CHEAT-EXEMPTION")
	run_state.bankroll = 500
	for item_id in ["xray_glasses", "tab_detector", "tarot_card"]:
		run_state.add_item(item_id)
	var environment := _surface_contract_environment()
	environment["game_states"] = {"pull_tabs": game.generate_environment_state(run_state, environment, run_state.create_rng("pull_tab_item_exemption_machine"))}
	run_state.current_environment = environment.duplicate(true)
	var cheat_action_ids: Array = []
	for action_value in game.cheat_actions(run_state, environment):
		if typeof(action_value) == TYPE_DICTIONARY:
			cheat_action_ids.append(str((action_value as Dictionary).get("id", "")))
	if cheat_action_ids != ["tab_detector_scan"]:
		failures.append("Pull Tabs exemption gained a distinct skill-cheat surface instead of retaining only its item-driven detector action: %s." % JSON.stringify(cheat_action_ids))
	var item_surface := game.surface_state(run_state, environment, {})
	var item_state: Dictionary = item_surface.get("pull_tab_item_state", {}) if typeof(item_surface.get("pull_tab_item_state", {})) == TYPE_DICTIONARY else {}
	if not bool(item_state.get("xray_available", false)) or (item_state.get("xray_targets", []) as Array).is_empty():
		failures.append("Pull Tabs x-ray glasses did not expose their seeded winner targets.")
	if not bool(item_state.get("tab_detector_available", false)):
		failures.append("Pull Tabs Tab Detector was not exposed as an available item interaction.")
	var scan_command := game.surface_action_command("pull_tab_detector_scan", 0, false, {}, run_state, environment)
	if not bool(scan_command.get("direct_resolve", false)) or not bool(scan_command.get("resolve", false)):
		failures.append("Pull Tabs owned-detector SCAN did not become a one-press toggle.")
	var heat_before_scan := run_state.suspicion_level()
	var scan_result := game.resolve_with_context("tab_detector_scan", 0, run_state, environment, run_state.create_rng("pull_tab_item_scan"), {})
	var scan_surface := game.surface_state(run_state, environment, {})
	var scan_state: Dictionary = scan_surface.get("pull_tab_item_state", {}) if typeof(scan_surface.get("pull_tab_item_state", {})) == TYPE_DICTIONARY else {}
	var scan_harness := SurfaceHarness.new()
	scan_harness.setup(scan_surface)
	game.draw_surface(scan_harness, scan_surface, {"contract_harness": true})
	if int(scan_result.get("suspicion_delta", -1)) != 0 or run_state.suspicion_level() != heat_before_scan:
		failures.append("Pull Tabs owned-detector SCAN added Heat.")
	if not bool(scan_state.get("tab_detector_active", false)) or not scan_harness.labels.has("SCAN"):
		failures.append("Pull Tabs owned-detector control did not activate and remain labeled SCAN.")
	var scan_off_result := game.resolve_with_context("tab_detector_scan", 0, run_state, environment, run_state.create_rng("pull_tab_item_scan_off"), {})
	var scan_off_state: Dictionary = game.surface_state(run_state, environment, {}).get("pull_tab_item_state", {})
	if int(scan_off_result.get("suspicion_delta", -1)) != 0 or bool(scan_off_state.get("tab_detector_active", true)):
		failures.append("Pull Tabs owned-detector SCAN did not switch off for zero Heat.")
	var detector_command := game.active_item_command("tab_detector", run_state, environment, run_state.create_rng("pull_tab_item_detector"))
	var detector_surface := game.surface_state(run_state, environment, {})
	var detector_state: Dictionary = detector_surface.get("pull_tab_item_state", {}) if typeof(detector_surface.get("pull_tab_item_state", {})) == TYPE_DICTIONARY else {}
	if not bool(detector_command.get("handled", false)) or not bool(detector_command.get("environment_changed", false)) or not bool(detector_state.get("tab_detector_active", false)) or int(detector_state.get("tab_detector_highlight_index", -1)) < 0:
		failures.append("Pull Tabs Tab Detector item did not activate its finite-deal highlight.")
	var tarot_command := game.active_item_command("tarot_card", run_state, environment, run_state.create_rng("pull_tab_item_tarot"))
	var tarot_surface := game.surface_state(run_state, environment, {})
	var tarot_state: Dictionary = tarot_surface.get("pull_tab_item_state", {}) if typeof(tarot_surface.get("pull_tab_item_state", {})) == TYPE_DICTIONARY else {}
	if not bool(tarot_command.get("handled", false)) or not bool(tarot_command.get("environment_changed", false)) or not bool(tarot_state.get("tarot_armed", false)):
		failures.append("Pull Tabs Tarot Card item did not arm its five-ticket reading.")


func _check_pull_tab_deal_variety(game: GameModule, failures: Array) -> void:
	var bar_run: RunState = RunStateScript.new()
	bar_run.start_new("PULL-TABS-BAR-VARIETY")
	var bar_environment := _surface_contract_environment()
	bar_environment["id"] = "pull-tabs-bar-variety"
	bar_environment["archetype_id"] = "bar"
	bar_environment["visual_context"] = {"scene_type": "bar"}
	var bar_machine := game.generate_environment_state(bar_run, bar_environment, bar_run.create_rng("pull_tab_bar_variety"))
	var gas_run: RunState = RunStateScript.new()
	gas_run.start_new("PULL-TABS-GAS-VARIETY")
	var gas_environment := _surface_contract_environment()
	gas_environment["id"] = "pull-tabs-gas-variety"
	gas_environment["archetype_id"] = "gas_station_casino"
	gas_environment["visual_context"] = {"scene_type": "gas_station_casino"}
	var gas_machine := game.generate_environment_state(gas_run, gas_environment, gas_run.create_rng("pull_tab_gas_variety"))
	var jazz_run: RunState = RunStateScript.new()
	jazz_run.start_new("PULL-TABS-JAZZ-VARIETY")
	var jazz_environment := _surface_contract_environment()
	jazz_environment["id"] = "pull-tabs-jazz-variety"
	jazz_environment["archetype_id"] = "jazz_club"
	jazz_environment["visual_context"] = {"scene_type": "jazz_club"}
	var jazz_machine := game.generate_environment_state(jazz_run, jazz_environment, jazz_run.create_rng("pull_tab_jazz_variety"))
	var bar_ids := _pull_tab_deal_ids(bar_machine)
	var gas_ids := _pull_tab_deal_ids(gas_machine)
	var jazz_ids := _pull_tab_deal_ids(jazz_machine)
	for ids_value in [bar_ids, gas_ids, jazz_ids]:
		var ids: Array = ids_value as Array
		if ids.size() != 4:
			failures.append("Pull Tabs venue variety generated %d deal windows instead of 4." % ids.size())
	if JSON.stringify(bar_ids) == JSON.stringify(gas_ids) or JSON.stringify(bar_ids) == JSON.stringify(jazz_ids) or JSON.stringify(gas_ids) == JSON.stringify(jazz_ids):
		failures.append("Pull Tabs venue deal windows did not vary across bar, gas-station, and jazz-club machines.")
	if str(bar_machine.get("machine_name", "")) == str(gas_machine.get("machine_name", "")):
		failures.append("Pull Tabs machine identity did not vary across venue types.")


func _check_pull_tab_full_deal_integrity(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("PULL-TABS-FULL-DEAL")
	run_state.bankroll = 100000
	var environment := _surface_contract_environment()
	environment["id"] = "pull-tabs-full-deal"
	environment["archetype_id"] = "bar"
	environment["visual_context"] = {"scene_type": "bar"}
	environment["game_states"] = {"pull_tabs": game.generate_environment_state(run_state, environment, run_state.create_rng("pull_tab_full_deal_machine"))}
	run_state.set_environment(environment)
	var active_environment: Dictionary = run_state.current_environment
	var machine: Dictionary = (active_environment.get("game_states", {}) as Dictionary).get("pull_tabs", {})
	var deals: Array = machine.get("deals", [])
	if deals.is_empty():
		failures.append("Pull Tabs full-deal check could not generate a deal.")
		return
	var deal_index := 0
	var initial_deal: Dictionary = deals[deal_index]
	var initial_remaining := int(initial_deal.get("remaining", 0))
	var expected_prizes := _pull_tab_remaining_prize_counts(initial_deal)
	var observed_prizes: Dictionary = {}
	var saw_last_tickets := false
	var restored_mid_deal := false
	for draw_index in range(initial_remaining):
		var command := game.surface_action_command("pull_tab_buy", deal_index, false, {}, run_state, active_environment)
		if str(command.get("action_id", "")) != "buy_tab":
			failures.append("Pull Tabs full-deal check could not buy ticket %d before sellout." % draw_index)
			return
		var result := game.resolve_with_context("buy_tab", int(command.get("set_stake", 1)), run_state, active_environment, run_state.create_rng("pull_tab_full_deal_%03d" % draw_index), command.get("ui_state", {}))
		_check_pull_tab_result_details(result, failures)
		var ticket: Dictionary = result.get("pull_tab_ticket", {})
		var payout := int(ticket.get("payout", 0))
		if payout > 0:
			var prize_key := _pull_tab_prize_key(ticket)
			observed_prizes[prize_key] = int(observed_prizes.get(prize_key, 0)) + 1
		var surface := game.surface_state(run_state, active_environment, {})
		var deal_view := _pull_tab_deal_view(surface, deal_index)
		var expected_remaining := initial_remaining - draw_index - 1
		if int(deal_view.get("remaining", -1)) != expected_remaining:
			failures.append("Pull Tabs full-deal depletion mismatch after ticket %d." % (draw_index + 1))
			return
		if expected_remaining > 0 and bool(deal_view.get("last_tickets", false)):
			saw_last_tickets = true
		if expected_remaining > 0 and expected_remaining <= 12 and not bool(deal_view.get("last_tickets", false)):
			failures.append("Pull Tabs last-tickets state did not become visible near sellout.")
		if not restored_mid_deal and draw_index >= int(initial_remaining / 2):
			run_state.set_environment(active_environment)
			var restored: RunState = RunStateScript.new()
			restored.from_dict(run_state.to_dict())
			run_state = restored
			active_environment = run_state.current_environment
			restored_mid_deal = true
	if not restored_mid_deal:
		failures.append("Pull Tabs full-deal check did not exercise save/load mid-deal.")
	var final_machine: Dictionary = (active_environment.get("game_states", {}) as Dictionary).get("pull_tabs", {})
	var final_deals: Array = final_machine.get("deals", [])
	var final_deal: Dictionary = final_deals[deal_index] if deal_index < final_deals.size() and typeof(final_deals[deal_index]) == TYPE_DICTIONARY else {}
	if int(final_deal.get("remaining", -1)) != 0 or not (final_deal.get("ticket_sleeve", []) as Array).is_empty():
		failures.append("Pull Tabs full-deal check did not exhaust the finite sleeve.")
	if int(final_deal.get("sold", 0)) != int(initial_deal.get("sold", 0)) + initial_remaining:
		failures.append("Pull Tabs full-deal sold count did not match consumed tickets.")
	_assert_pull_tab_prize_counts(expected_prizes, observed_prizes, "Pull Tabs full-deal prize counts did not match the original sleeve.", failures)
	var sold_out_surface := game.surface_state(run_state, active_environment, {})
	var sold_out_view := _pull_tab_deal_view(sold_out_surface, deal_index)
	if str(sold_out_view.get("tension_state", "")) != "sold_out" or bool(sold_out_view.get("enabled", true)):
		failures.append("Pull Tabs sold-out deal did not expose a disabled sold_out tension state.")
	if int(sold_out_view.get("top_prize_remaining", -1)) != 0 or bool(sold_out_view.get("top_prize_available", true)):
		failures.append("Pull Tabs top-prize tracking still showed an available top prize after full deal exhaustion.")
	var sold_out_command := game.surface_action_command("pull_tab_buy", deal_index, false, {}, run_state, active_environment)
	if str(sold_out_command.get("action_id", "")) == "buy_tab":
		failures.append("Pull Tabs sold-out row still mapped to a buy action.")
	if not saw_last_tickets:
		failures.append("Pull Tabs full-deal check never observed the last-tickets tension state.")


func _pull_tab_deal_ids(machine: Dictionary) -> Array:
	var result: Array = []
	for deal_value in machine.get("deals", []):
		if typeof(deal_value) == TYPE_DICTIONARY:
			result.append(str((deal_value as Dictionary).get("id", "")))
	return result


func _pull_tab_remaining_prize_counts(deal: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for prize_value in deal.get("prizes", []):
		if typeof(prize_value) != TYPE_DICTIONARY:
			continue
		var prize: Dictionary = prize_value
		var remaining := maxi(0, int(prize.get("remaining", prize.get("count", 0))))
		if remaining <= 0:
			continue
		result[_pull_tab_prize_key(prize)] = remaining
	return result


func _assert_pull_tab_prize_counts(expected: Dictionary, observed: Dictionary, message: String, failures: Array) -> void:
	for key in expected.keys():
		if int(observed.get(key, -1)) != int(expected.get(key, 0)):
			failures.append(message)
			return
	for key in observed.keys():
		if not expected.has(key):
			failures.append(message)
			return


func _pull_tab_prize_key(source: Dictionary) -> String:
	return "%s|%d" % [str(source.get("prize_label", source.get("label", ""))), maxi(0, int(source.get("payout", 0)))]


func _pull_tab_deal_view(surface: Dictionary, deal_index: int) -> Dictionary:
	for deal_value in surface.get("pull_tab_deals", []):
		if typeof(deal_value) == TYPE_DICTIONARY and int((deal_value as Dictionary).get("index", -1)) == deal_index:
			return (deal_value as Dictionary).duplicate(true)
	return {}


func _check_pull_tab_tarot_reading_surface(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("PULL-TABS-TAROT-READING")
	run_state.bankroll = 500
	run_state.add_item("tarot_card")
	run_state.set_active_item("tarot_card")
	var environment := _surface_contract_environment()
	var machine := game.generate_environment_state(run_state, environment, run_state.create_rng("pull_tab_tarot_machine"))
	var deals: Array = machine.get("deals", [])
	if deals.is_empty():
		failures.append("Pull Tabs tarot check could not generate a deal row.")
		return
	var deal: Dictionary = deals[0]
	var prizes: Array = deal.get("prizes", [])
	var winner_indices: Array = []
	for index in range(prizes.size()):
		if typeof(prizes[index]) != TYPE_DICTIONARY:
			continue
		if int((prizes[index] as Dictionary).get("payout", 0)) > 0:
			winner_indices.append(index)
	if winner_indices.is_empty():
		failures.append("Pull Tabs tarot check could not find a winning prize row.")
		return
	var first_winner := int(winner_indices[0])
	var second_winner := int(winner_indices[mini(1, winner_indices.size() - 1)])
	var controlled_sleeve := [-1, -1, first_winner, -1, second_winner, -1]
	var remaining_counts: Array = []
	for _index in range(prizes.size()):
		remaining_counts.append(0)
	for entry in controlled_sleeve:
		var prize_index := int(entry)
		if prize_index >= 0 and prize_index < remaining_counts.size():
			remaining_counts[prize_index] = int(remaining_counts[prize_index]) + 1
	var controlled_prizes: Array = []
	for index in range(prizes.size()):
		var prize: Dictionary = (prizes[index] as Dictionary).duplicate(true) if typeof(prizes[index]) == TYPE_DICTIONARY else {}
		prize["remaining"] = int(remaining_counts[index])
		controlled_prizes.append(prize)
	deal["ticket_sleeve"] = controlled_sleeve
	deal["remaining"] = controlled_sleeve.size()
	deal["sold"] = 0
	deal["unit_cursor"] = int(deal.get("initial_removed_count", 0))
	deal["prizes"] = controlled_prizes
	deals[0] = deal
	machine["deals"] = deals
	environment["game_states"] = {"pull_tabs": machine}
	var arm_command := game.active_item_command("tarot_card", run_state, environment, run_state.create_rng("pull_tab_tarot_arm"))
	if not bool(arm_command.get("handled", false)) or not bool(arm_command.get("environment_changed", false)):
		failures.append("Pull Tabs tarot active item did not arm the next ticket.")
	var buy_command := game.surface_action_command("pull_tab_buy", 0, false, {}, run_state, environment)
	var buy_result := game.resolve_with_context("buy_tab", int(buy_command.get("set_stake", 1)), run_state, environment, run_state.create_rng("pull_tab_tarot_buy"), buy_command.get("ui_state", {}))
	_check_pull_tab_result_details(buy_result, failures)
	var ticket: Dictionary = buy_result.get("pull_tab_ticket", {})
	if not bool(ticket.get("tarot_converted", false)):
		failures.append("Pull Tabs tarot purchase did not convert the bought ticket into a burned loser.")
	var reading: Array = ticket.get("tarot_reading", [])
	if reading.size() != 5:
		failures.append("Pull Tabs tarot reading did not store exactly the next five ticket outcomes.")
	var found_winner := false
	for row_value in reading:
		if typeof(row_value) == TYPE_DICTIONARY and int((row_value as Dictionary).get("payout", 0)) > 0:
			found_winner = true
			break
	if not found_winner:
		failures.append("Pull Tabs tarot reading missed controlled winning tickets in the next five outcomes.")
	var collect_command := game.surface_action_command("pull_tab_collect_tray", 0, false, {}, run_state, environment)
	var surface := game.surface_state(run_state, environment, collect_command.get("ui_state", {}))
	var stack: Array = surface.get("pull_tab_stack", [])
	if stack.is_empty():
		failures.append("Pull Tabs tarot ticket did not render in the collected play stack.")
	else:
		var stack_ticket: Dictionary = stack[0]
		if (stack_ticket.get("tarot_reading", []) as Array).size() != 5:
			failures.append("Pull Tabs tarot stack view dropped the next-five reading.")
		if (stack_ticket.get("prize_rows", []) as Array).is_empty():
			failures.append("Pull Tabs tarot stack view dropped the ticket prize legend.")


# Bar dice is a full-simulation Ship, Captain, Crew table: cargo scoring,
# keep/reroll interaction, loaded/palmed cheat heat, pot carryovers, and rake
# tuning must stay stable.
func _check_bar_dice_contract(library: ContentLibrary, failures: Array) -> void:
	var game: GameModule = _load_surface_contract_game(library, "bar_dice", failures)
	if game == null:
		return
	if not game.is_full_simulation():
		failures.append("Bar Dice must report the full-simulation gameplay model.")
	_check_bar_dice_scoring(game, failures)
	_check_bar_dice_generated_identity(game, failures)
	_check_bar_dice_surface_contract(game, failures)
	_check_bar_dice_result_visible(game, failures)
	_check_bar_dice_keep_reroll(game, failures)
	_check_bar_dice_patron_turn_determinism(game, failures)
	_check_bar_dice_match_and_bonuses(game, failures)
	_check_bar_dice_stake_lifecycle(game, failures)
	_check_bar_dice_cheat(game, failures)
	_check_bar_dice_item_luck_alcohol(game, failures)
	_check_bar_dice_edge_band(game, library, failures)
	_check_bar_dice_save_load(game, failures)


# Guards against the surface stranding in the keep/reroll phase after a round
# resolves: the resolving command must release UI-local state so the host clears
# `rolled` and the next surface_state shows the settled house reveal and result.
func _check_bar_dice_result_visible(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("BAR-DICE-RESULT-VISIBLE")
	run_state.bankroll = 500
	var environment := _surface_contract_environment()
	environment["game_states"] = {"bar_dice": game.generate_environment_state(run_state, environment, run_state.create_rng("bar_dice_visible_state"))}
	run_state.current_environment = environment.duplicate(true)
	var roll_cmd := game.surface_action_command("bar_dice_roll", 0, false, {}, run_state, run_state.current_environment)
	var rolled_ui: Dictionary = roll_cmd.get("ui_state", {})
	# A confirmed resolve must resolve and must NOT preserve UI-local state, or the
	# host keeps `rolled` set and the surface never leaves the select phase.
	var confirm_cmd := game.surface_action_command("bar_dice_resolve", 0, true, rolled_ui, run_state, run_state.current_environment)
	if not bool(confirm_cmd.get("resolve", false)):
		failures.append("Bar Dice confirmed resolve did not request resolution.")
	if bool(confirm_cmd.get("preserve_surface_ui_state", false)):
		failures.append("Bar Dice resolving command preserved UI-local state, stranding the surface in the select phase.")
	var result := game.resolve_with_context("roll", 8, run_state, run_state.current_environment, run_state.create_rng("bar_dice_visible_resolve"), confirm_cmd.get("ui_state", rolled_ui))
	if not bool(result.get("ok", false)):
		failures.append("Bar Dice resolve did not complete a round.")
	# Emulate the host clearing UI-local state after a non-preserving resolve.
	var settled := game.surface_state(run_state, run_state.current_environment, {})
	if str(settled.get("phase", "")) != "settled":
		failures.append("Bar Dice surface did not show the settled result after resolving (phase=%s)." % str(settled.get("phase", "")))
	if not bool(settled.get("house_revealed", false)):
		failures.append("Bar Dice settled surface did not reveal the house dice after resolving.")
	if str(settled.get("result_message", "")).strip_edges().is_empty():
		failures.append("Bar Dice settled surface did not expose the round result message after resolving.")


func _check_bar_dice_scoring(game: GameModule, failures: Array) -> void:
	var no_ship: Dictionary = game.call("_score", [5, 4, 3, 2, 1])
	if str(no_ship.get("category", "")) != "not_qualified" or bool(no_ship.get("qualified", true)) or int(no_ship.get("cargo", -1)) != 0:
		failures.append("Bar Dice did not score a hand without Ship as unqualified.")
	var ship_only: Dictionary = game.call("_score", [6, 4, 3, 2, 1])
	if str(ship_only.get("category", "")) != "ship_only" or int(ship_only.get("cargo", -1)) != 0:
		failures.append("Bar Dice did not identify Ship without Captain/Crew and zero cargo.")
	var ship_captain: Dictionary = game.call("_score", [6, 5, 3, 2, 1])
	if str(ship_captain.get("category", "")) != "ship_captain" or int(ship_captain.get("cargo", -1)) != 0:
		failures.append("Bar Dice did not identify Ship + Captain without Crew and zero cargo.")
	var cargo_five: Dictionary = game.call("_score", [6, 5, 4, 3, 2])
	if str(cargo_five.get("category", "")) != "ship_captain_crew" or int(cargo_five.get("cargo", 0)) != 5:
		failures.append("Bar Dice did not score qualified cargo from the two remaining dice.")
	var unordered_qualified: Dictionary = game.call("_score", [5, 6, 4, 3, 2])
	if str(unordered_qualified.get("category", "")) != "ship_captain_crew" or int(unordered_qualified.get("cargo", 0)) != 5:
		failures.append("Bar Dice did not lock Ship, Captain, Crew in acquisition order independent of die position.")
	var perfect_cargo: Dictionary = game.call("_score_for_ruleset", [6, 5, 4, 6, 6], "ship_captain_crew")
	if str(perfect_cargo.get("category", "")) != "perfect_cargo" or int(perfect_cargo.get("cargo", 0)) != 12:
		failures.append("Bar Dice did not score double-six cargo as the top Ship, Captain, Crew result.")
	if int(game.call("_compare_signatures", perfect_cargo.get("signature", []), cargo_five.get("signature", []))) <= 0:
		failures.append("Bar Dice perfect cargo did not beat lower qualified cargo.")
	if int(game.call("_compare_signatures", cargo_five.get("signature", []), ship_captain.get("signature", []))) <= 0:
		failures.append("Bar Dice qualified cargo did not beat an unqualified Ship + Captain hand.")
	var same_cargo: Dictionary = game.call("_score", [6, 5, 4, 2, 3])
	if int(game.call("_compare_signatures", cargo_five.get("signature", []), same_cargo.get("signature", []))) != 0:
		failures.append("Bar Dice equal cargo did not compare as a tie.")
	var marks: Array = game.call("_suggested_reroll_for_ruleset", [6, 5, 3, 2, 1], "ship_captain_crew")
	if marks.has(0) or marks.has(1) or not marks.has(2):
		failures.append("Bar Dice suggested reroll did not lock Ship/Captain while chasing Crew.")
	var no_ship_marks: Array = game.call("_suggested_reroll_for_ruleset", [5, 4, 3, 2, 1], "ship_captain_crew")
	if no_ship_marks.size() != 5:
		failures.append("Bar Dice suggested reroll incorrectly banked Captain/Crew before Ship.")
	var crew_before_captain_marks: Array = game.call("_suggested_reroll_for_ruleset", [6, 4, 3, 2, 1], "ship_captain_crew")
	if crew_before_captain_marks.has(0) or not crew_before_captain_marks.has(1):
		failures.append("Bar Dice suggested reroll incorrectly banked Crew before Captain.")
	var cargo_marks: Array = game.call("_suggested_reroll_for_ruleset", [6, 5, 4, 3, 2], "ship_captain_crew")
	if JSON.stringify(cargo_marks) != JSON.stringify([3, 4]):
		failures.append("Bar Dice suggested reroll did not leave only cargo dice live after 6-5-4.")
	var perfect_marks: Array = game.call("_suggested_reroll_for_ruleset", [6, 5, 4, 6, 6], "ship_captain_crew")
	if not perfect_marks.is_empty():
		failures.append("Bar Dice suggested reroll did not hold perfect cargo.")


func _check_bar_dice_generated_identity(game: GameModule, failures: Array) -> void:
	var run_a: RunState = RunStateScript.new()
	run_a.start_new("BAR-DICE-GENERATED-A")
	var environment_a := _surface_contract_environment()
	var state_a: Dictionary = game.generate_environment_state(run_a, environment_a, run_a.create_rng("bar_dice_identity"))
	var run_b: RunState = RunStateScript.new()
	run_b.start_new("BAR-DICE-GENERATED-A")
	var environment_b := _surface_contract_environment()
	var state_b: Dictionary = game.generate_environment_state(run_b, environment_b, run_b.create_rng("bar_dice_identity"))
	if JSON.stringify(state_a) != JSON.stringify(state_b):
		failures.append("Bar Dice generated table identity is not deterministic for the same seed.")
	for required_key in ["ruleset_family", "available_variants", "edge_tier", "stake_ladder", "carryover_pot", "loaded_die", "patrons", "dealer_profile", "table_key", "rake_percent"]:
		if not state_a.has(required_key):
			failures.append("Bar Dice generated state is missing %s." % required_key)
	if str(state_a.get("ruleset_family", "")) != "ship_captain_crew":
		failures.append("Bar Dice generated state did not select the release Ship, Captain, Crew ruleset.")
	var ladder: Array = state_a.get("stake_ladder", [])
	if ladder.size() < 3:
		failures.append("Bar Dice generated chip ladder is too shallow.")
	if (state_a.get("patrons", []) as Array).is_empty():
		failures.append("Bar Dice generated state did not seed table patrons.")
	var patrons: Array = state_a.get("patrons", [])
	var found_regular := false
	var banter_heads := {}
	for patron_value in patrons:
		var patron: Dictionary = patron_value if typeof(patron_value) == TYPE_DICTIONARY else {}
		if str(patron.get("id", "")) == "knucklebones_nell":
			found_regular = true
		if str(patron.get("personality", "")).strip_edges().is_empty() or (patron.get("banter_lines", []) as Array).size() < 2:
			failures.append("Bar Dice generated patron is missing readable personality/banter data.")
			break
		var banter_lines: Array = patron.get("banter_lines", [])
		banter_heads[str(banter_lines[0])] = true
	if not found_regular:
		failures.append("Bar Dice generated table did not include the memorable regular Knucklebones Nell.")
	if banter_heads.size() < mini(2, patrons.size()):
		failures.append("Bar Dice generated patron banter did not vary across the table.")
	if (state_a.get("available_variants", []) as Array).is_empty():
		failures.append("Bar Dice generated state did not expose the variation catalog.")


func _check_bar_dice_surface_contract(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("BAR-DICE-SURFACE-CONTRACT")
	var environment := _surface_contract_environment()
	var generated_state := game.generate_environment_state(run_state, environment, run_state.create_rng("bar_dice_contract_state"))
	if generated_state.is_empty():
		failures.append("Bar Dice did not generate table identity state.")
	environment["game_states"] = {"bar_dice": generated_state}
	var surface := game.surface_state(run_state, environment, {})
	if str(surface.get("surface_renderer", "")) != "dice_table":
		failures.append("Bar Dice surface did not route to the dice-table renderer.")
	_check_idle_animation_liveness_contract(surface, "Bar Dice table surface", failures)
	if str(surface.get("surface_life", "")) != "bar_dice_table" or str(surface.get("surface_cast", "")) != "dealer_table":
		failures.append("Bar Dice surface did not expose the table-game life/cast metadata.")
	if not bool(surface.get("surface_controls_native", false)):
		failures.append("Bar Dice surface did not expose native surface controls.")
	if not bool(surface.get("surface_embeds_outcomes", false)):
		failures.append("Bar Dice surface did not declare embedded outcomes.")
	var bar_dice_round_timer: Dictionary = surface.get("table_round_timer", {}) if typeof(surface.get("table_round_timer", {})) == TYPE_DICTIONARY else {}
	if bar_dice_round_timer.is_empty() or (surface.get("patrons", []) as Array).is_empty():
		failures.append("Bar Dice table surface did not expose timer/patron state.")
	if bool(surface.get("surface_realtime_state_refresh", false)):
		failures.append("Bar Dice static table surface should not request full snapshot refreshes.")
	if not bool(surface.get("surface_animates_idle", false)):
		failures.append("Bar Dice table surface must declare idle animation liveness for rail, timer, and table motion.")
	if bool(surface.get("surface_stake_controls_required", true)):
		failures.append("Bar Dice should use its generated chip ladder instead of host stake controls.")
	if (surface.get("player", []) as Array).size() != 5:
		failures.append("Bar Dice surface did not expose a five-die player cup.")
	var opponent_rows: Array = surface.get("opponent_rows", [])
	if opponent_rows.size() < 2:
		failures.append("Bar Dice surface did not expose visible dice cups for other table players.")
	else:
		for row_value in opponent_rows:
			var row: Dictionary = row_value
			if (row.get("dice", []) as Array).size() != 5:
				failures.append("Bar Dice opponent row did not expose a five-die cup.")
				break
	if (surface.get("paytable_rows", []) as Array).is_empty():
		failures.append("Bar Dice surface did not expose the paytable for the info panel.")
	if (surface.get("patrons", []) as Array).is_empty() or not ((surface.get("dealer_profile", {}) as Dictionary).has("name")):
		failures.append("Bar Dice surface did not expose table-game patrons and dealer profile.")
	var surface_patrons: Array = surface.get("patrons", [])
	var regular_visible := false
	for patron_value in surface_patrons:
		var patron: Dictionary = patron_value if typeof(patron_value) == TYPE_DICTIONARY else {}
		if str(patron.get("id", "")) == str(surface.get("table_regular_id", "")):
			regular_visible = true
		if str(patron.get("personality", "")).strip_edges().is_empty() or str(patron.get("banter", "")).strip_edges().is_empty():
			failures.append("Bar Dice surface patron did not expose readable personality and banter.")
			break
	if not regular_visible:
		failures.append("Bar Dice surface did not keep the memorable regular visible at the rail.")
	if str(surface.get("patron_wager_action", "")) != "bar_dice_rail_bet":
		failures.append("Bar Dice surface did not expose the rail-bet patron action.")
	var pacing: Dictionary = surface.get("bar_dice_pacing", {}) if typeof(surface.get("bar_dice_pacing", {})) == TYPE_DICTIONARY else {}
	if str(pacing.get("patron_turn_model", "")) != "simultaneous_cups" or int(pacing.get("patron_dead_wait_msec", -1)) != 0:
		failures.append("Bar Dice surface did not expose snappy simultaneous patron-turn pacing.")
	if (surface.get("available_variants", []) as Array).is_empty():
		failures.append("Bar Dice surface did not expose future variation metadata.")
	if (surface.get("table_round_timer", {}) as Dictionary).is_empty():
		failures.append("Bar Dice surface did not expose the shared table-round timer.")
	if (surface.get("bar_dice_explainer", {}) as Dictionary).is_empty():
		failures.append("Bar Dice surface did not expose a player-facing rules/progress explainer.")
	var turn_guide: Dictionary = surface.get("bar_dice_turn_guide", {}) if typeof(surface.get("bar_dice_turn_guide", {})) == TYPE_DICTIONARY else {}
	if turn_guide.is_empty() or str(turn_guide.get("goal", "")).find("6") == -1 or str(turn_guide.get("next_step", "")).is_empty():
		failures.append("Bar Dice surface did not expose beginner-friendly goal and next-step guidance.")
	var rules_lines: Array = surface.get("bar_dice_rules_lines", []) if typeof(surface.get("bar_dice_rules_lines", [])) == TYPE_ARRAY else []
	if rules_lines.size() < 4:
		failures.append("Bar Dice surface did not expose compact on-screen rules lines.")
	for line_value in rules_lines:
		if str(line_value).length() > 48:
			failures.append("Bar Dice rules line is too long for the compact rules panel: %s." % str(line_value))
			break
	var bar_layout: Dictionary = surface.get("bar_dice_layout", {}) if typeof(surface.get("bar_dice_layout", {})) == TYPE_DICTIONARY else {}
	var text_panel_rects: Array = bar_layout.get("text_panel_rects", []) if typeof(bar_layout.get("text_panel_rects", [])) == TYPE_ARRAY else []
	var patron_safe_rects: Array = bar_layout.get("patron_safe_rects", []) if typeof(bar_layout.get("patron_safe_rects", [])) == TYPE_ARRAY else []
	if text_panel_rects.size() < 2 or patron_safe_rects.size() < 2:
		failures.append("Bar Dice surface did not expose text-panel and player-safe layout metadata.")
	var game_board := Rect2(Vector2.ZERO, Vector2(ArtContractsScript.GAME_BOARD_SIZE))
	for panel_value in text_panel_rects:
		var panel_rect := _layout_rect_from_dict(panel_value)
		if panel_rect.size.x <= 0.0 or panel_rect.size.y <= 0.0 or panel_rect.position.x < 0.0 or panel_rect.position.y < 0.0 or panel_rect.end.x > game_board.end.x or panel_rect.end.y > game_board.end.y:
			failures.append("Bar Dice text panel is outside the game board: %s." % str(panel_rect))
		var panel_id := str((panel_value as Dictionary).get("id", "")) if typeof(panel_value) == TYPE_DICTIONARY else ""
		if panel_id == "rules" and panel_rect.size.y >= 64.0:
			failures.append("Bar Dice rules panel stayed too large after the compact layout pass.")
		for patron_value in patron_safe_rects:
			var patron_rect := _layout_rect_from_dict(patron_value)
			if panel_rect.intersects(patron_rect):
				failures.append("Bar Dice text panel overlaps a table player: %s intersects %s." % [str(panel_rect), str(patron_rect)])
				break
	for i in range(patron_safe_rects.size()):
		var patron_a := _layout_rect_from_dict(patron_safe_rects[i])
		for j in range(i + 1, patron_safe_rects.size()):
			var patron_b := _layout_rect_from_dict(patron_safe_rects[j])
			if patron_a.intersects(patron_b):
				failures.append("Bar Dice table player regions overlap: %s intersects %s." % [str(patron_a), str(patron_b)])
	if (surface.get("dice_legend", []) as Array).size() < 3:
		failures.append("Bar Dice surface did not expose locked/suggested/selected dice legend data.")
	if not _surface_blocks_action_while(surface, "bar_dice_select", "bar_dice_tumble") or not _surface_blocks_action_while(surface, "bar_dice_shake", "bar_dice_tumble"):
		failures.append("Bar Dice surface did not block dice input during the tumble animation.")
	if (surface.get("stake_ladder", []) as Array).size() < 3 or int(surface.get("active_stake", 0)) <= 0:
		failures.append("Bar Dice surface did not expose a generated chip ladder and active stake.")
	if str(surface.get("ruleset_family", "")) != "ship_captain_crew" or str(surface.get("bonus_mode", "")).is_empty():
		failures.append("Bar Dice surface did not expose generated table identity.")
	if int(surface.get("pot_meter", 0)) <= int(surface.get("active_stake", 0)):
		failures.append("Bar Dice surface did not expose the shared table pot meter.")
	var bar_dice_harness := SurfaceHarness.new()
	bar_dice_harness.setup(surface)
	game.draw_surface(bar_dice_harness, surface, {"contract_harness": true})
	var bar_dice_roll_hit := _surface_harness_first_hit(bar_dice_harness, "bar_dice_roll", 0)
	_check_canvas_hit_dispatch(surface, bar_dice_roll_hit.get("rect", Rect2()), "bar_dice_roll", 0, "Bar Dice roll canvas dispatch", failures)
	var highest_stake_index := (surface.get("stake_ladder", []) as Array).size() - 1
	var highest_stake_hit := _surface_harness_first_hit(bar_dice_harness, "bar_dice_stake", highest_stake_index)
	_check_canvas_hit_dispatch(surface, highest_stake_hit.get("rect", Rect2()), "bar_dice_stake", highest_stake_index, "Bar Dice highest-stake canvas dispatch", failures)
	var highest_stake_click := _check_surface_command_non_mutating(game, "bar_dice_stake", highest_stake_index, false, {}, run_state, environment, "bar dice highest stake", failures)
	var highest_stake_ui: Dictionary = highest_stake_click.get("ui_state", {})
	var highest_stake_surface := game.surface_state(run_state, environment, highest_stake_ui)
	var stake_ladder: Array = surface.get("stake_ladder", [])
	if int(highest_stake_ui.get("selected_stake_index", -1)) != highest_stake_index or int(highest_stake_surface.get("active_stake", -1)) != int(stake_ladder[highest_stake_index]):
		failures.append("Bar Dice highest chip did not remain selected after rebuilding the surface.")
	var stake_click := _check_surface_command_non_mutating(game, "bar_dice_stake", 0, false, {}, run_state, environment, "bar dice stake", failures)
	if int((stake_click.get("ui_state", {}) as Dictionary).get("selected_stake_index", -1)) != 0:
		failures.append("Bar Dice chip selection did not update UI-local stake state.")
	var roll_click := _check_surface_command_non_mutating(game, "bar_dice_roll", 0, false, {}, run_state, environment, "bar dice roll", failures)
	var rolled_state: Dictionary = roll_click.get("ui_state", {})
	if not bool(rolled_state.get("rolled", false)) or (rolled_state.get("dice", []) as Array).size() != 5:
		failures.append("Bar Dice roll did not open a five-die keep/reroll phase as UI-local state.")
	var select_surface := game.surface_state(run_state, environment, rolled_state)
	if str(select_surface.get("phase", "")) != "select":
		failures.append("Bar Dice did not enter the keep/reroll select phase after a roll.")
	var select_guide: Dictionary = select_surface.get("bar_dice_turn_guide", {}) if typeof(select_surface.get("bar_dice_turn_guide", {})) == TYPE_DICTIONARY else {}
	if str(select_guide.get("next_step", "")).find("Click") == -1 or str(select_guide.get("shake_hint", "")).find("SHAKE") == -1 or str(select_guide.get("shake_hint", "")).find("only") == -1:
		failures.append("Bar Dice select phase did not explain clicking dice, shaking, and settling.")
	var select_buttons: Array = select_surface.get("bar_dice_action_buttons", [])
	var found_shake_button := false
	var found_settle_button := false
	for button_value in select_buttons:
		var button: Dictionary = button_value
		var button_action := str(button.get("action", ""))
		if button_action == "bar_dice_shake" and str(button.get("label", "")).find("DICE") >= 0 and str(button.get("detail", "")).find("Reroll") >= 0:
			found_shake_button = true
		if button_action == "bar_dice_resolve" and str(button.get("label", "")).find("SETTLE") >= 0 and str(button.get("detail", "")).find("Compare") >= 0:
			found_settle_button = true
	if not found_shake_button or not found_settle_button:
		failures.append("Bar Dice action buttons did not describe their reroll/settle behavior.")
	if (select_surface.get("animated_dice_indices", []) as Array).size() != 5:
		failures.append("Bar Dice opening roll did not mark all dice as rolling.")
	var select_harness := SurfaceHarness.new()
	select_harness.setup(select_surface)
	game.draw_surface(select_harness, select_surface, {"contract_harness": true})
	if _surface_hit_count(select_harness, "bar_dice_select") < 5:
		failures.append("Bar Dice select phase did not register every die as an interactive reroll target.")
	var suggested_marks: Array = select_surface.get("suggested_reroll", [])
	if suggested_marks.is_empty():
		failures.append("Bar Dice opening roll did not expose any legal keep/reroll choice for the surface test.")
	else:
		var mark_index := int(suggested_marks[0])
		var mark_click := _check_surface_command_non_mutating(game, "bar_dice_select", mark_index, false, rolled_state, run_state, environment, "bar dice select", failures)
		var marked_state: Dictionary = mark_click.get("ui_state", {})
		if not (marked_state.get("reroll", []) as Array).has(mark_index):
			failures.append("Bar Dice die click did not mark the die for reroll.")
		var dice_before_shake: Array = marked_state.get("dice", [])
		var shake_click := _check_surface_command_non_mutating(game, "bar_dice_shake", 0, false, marked_state, run_state, environment, "bar dice shake marked", failures)
		var shaken_state: Dictionary = shake_click.get("ui_state", {})
		var last_rerolled: Array = shaken_state.get("last_rerolled", [])
		if last_rerolled.size() != 1 or int(last_rerolled[0]) != mark_index:
			failures.append("Bar Dice shake did not report only the marked die as rerolled.")
		var shake_surface := game.surface_state(run_state, environment, shaken_state)
		var animated_indices: Array = shake_surface.get("animated_dice_indices", [])
		if animated_indices.size() != 1 or int(animated_indices[0]) != mark_index:
			failures.append("Bar Dice reroll animation was not limited to the marked die.")
		var dice_after_shake: Array = shaken_state.get("dice", [])
		for die_index in range(dice_before_shake.size()):
			if die_index != mark_index and int(dice_before_shake[die_index]) != int(dice_after_shake[die_index]):
				failures.append("Bar Dice shake moved a kept die that was not marked for reroll.")
				break
	var resolve_click := game.surface_action_command("bar_dice_resolve", 0, false, rolled_state, run_state, environment)
	if str(resolve_click.get("action_id", "")) != "roll" or str(resolve_click.get("action_kind", "")) != "legal":
		failures.append("Bar Dice resolve did not map to the legal roll action.")
	var load_click := _check_surface_command_non_mutating(game, "bar_dice_load", 0, false, rolled_state, run_state, environment, "bar dice load", failures)
	if str(load_click.get("action_id", "")) != "loaded_toss" or str(load_click.get("action_kind", "")) != "cheat":
		failures.append("Bar Dice loaded toss did not map to the risky cheat action.")
	var load_state: Dictionary = load_click.get("ui_state", {})
	if int(load_state.get("loaded_value", 0)) < 1:
		failures.append("Bar Dice loaded toss did not arm a rigged die value hint.")
	var controlled_roll: Dictionary = load_state.get("controlled_roll", {}) if typeof(load_state.get("controlled_roll", {})) == TYPE_DICTIONARY else {}
	if controlled_roll.is_empty():
		failures.append("Bar Dice loaded toss did not create a controlled-roll timing challenge.")
	var release_surface := game.surface_state(run_state, environment, load_state)
	if not bool(release_surface.get("controlled_roll_ready", false)):
		failures.append("Bar Dice loaded surface did not expose controlled-roll ready state.")
	var release_harness := SurfaceHarness.new()
	release_harness.setup(release_surface)
	game.draw_surface(release_harness, release_surface, {"contract_harness": true})
	if not _surface_harness_has_action(release_harness, "bar_dice_release"):
		failures.append("Bar Dice controlled-roll surface is missing the RELEASE timing control.")
	load_state["controlled_roll_input_msec"] = int(controlled_roll.get("target_msec", 0))
	var release_click := game.surface_action_command("bar_dice_release", 0, false, load_state, run_state, environment)
	var release_state: Dictionary = release_click.get("ui_state", {})
	var released_roll: Dictionary = release_state.get("controlled_roll", {}) if typeof(release_state.get("controlled_roll", {})) == TYPE_DICTIONARY else {}
	if str(released_roll.get("skill_grade", "")) != "perfect":
		failures.append("Bar Dice RELEASE did not grade a perfect controlled-roll input.")
	var cheat_settle := game.surface_action_command("bar_dice_resolve", 0, true, release_state, run_state, environment)
	if str(cheat_settle.get("action_id", "")) != "loaded_toss" or str(cheat_settle.get("action_kind", "")) != "cheat" or not bool(cheat_settle.get("resolve", false)):
		failures.append("Bar Dice SETTLE did not resolve the armed controlled-roll cheat.")
	var palm_click := _check_surface_command_non_mutating(game, "bar_dice_palm", 0, false, rolled_state, run_state, environment, "bar dice palm", failures)
	if str(palm_click.get("action_id", "")) != "palmed_swap" or str(palm_click.get("action_kind", "")) != "cheat" or bool(palm_click.get("resolve", false)):
		failures.append("Bar Dice palmed swap did not map to the second cheat action.")
	var palm_ui: Dictionary = palm_click.get("ui_state", {})
	var palm_challenge: Dictionary = palm_ui.get("palmed_swap_challenge", {}) if typeof(palm_ui.get("palmed_swap_challenge", {})) == TYPE_DICTIONARY else {}
	var palm_live_surface := game.surface_state(run_state, environment, palm_ui)
	if palm_challenge.is_empty() or not bool(palm_live_surface.get("palmed_swap_ready", false)) or not bool(palm_live_surface.get("surface_realtime_state_refresh", false)):
		failures.append("Bar Dice palmed swap did not expose a live timing challenge.")
	palm_ui["surface_time_msec"] = int(palm_challenge.get("target_msec", 0))
	var palm_lock := game.surface_action_command("bar_dice_palm", 0, false, palm_ui, run_state, environment)
	var palm_lock_challenge: Dictionary = (palm_lock.get("ui_state", {}) as Dictionary).get("palmed_swap_challenge", {})
	if not bool(palm_lock.get("resolve", false)) or str(palm_lock_challenge.get("skill_grade", "")) != "perfect":
		failures.append("Bar Dice SWAP NOW input did not resolve a perfect palmed-swap timing lock.")
	var selected_state := rolled_state.duplicate(true)
	selected_state["selected_action_id"] = "loaded_toss"
	selected_state["selected_action_kind"] = "cheat"
	var loaded_surface := game.surface_state(run_state, environment, selected_state)
	if not (loaded_surface.get("native_selected_surface_actions", []) as Array).has("bar_dice_load"):
		failures.append("Bar Dice surface did not mark the loaded toss region selected.")
	if not (loaded_surface.get("native_selected_surface_actions", []) as Array).has("bar_dice_release"):
		failures.append("Bar Dice surface did not mark the controlled-roll release region selected.")
	var palm_surface := game.surface_state(run_state, environment, palm_ui)
	if not (palm_surface.get("native_selected_surface_actions", []) as Array).has("bar_dice_palm"):
		failures.append("Bar Dice surface did not mark the palmed swap region selected.")
	if (loaded_surface.get("surface_animation_channels", []) as Array).is_empty():
		failures.append("Bar Dice surface did not declare a tumble animation channel.")


func _check_bar_dice_keep_reroll(game: GameModule, failures: Array) -> void:
	# Keeping every die versus rerolling every die from the same opening and stream
	# must produce different final dice, proving keep/reroll affects the outcome.
	var keep_all := _bar_dice_resolve_with_reroll(game, "BAR-DICE-KEEP-REROLL", [])
	var reroll_all := _bar_dice_resolve_with_reroll(game, "BAR-DICE-KEEP-REROLL", [0, 1, 2, 3, 4])
	var kept_dice: Array = keep_all.get("bar_dice_player_dice", [])
	var rerolled_dice: Array = reroll_all.get("bar_dice_player_dice", [])
	if kept_dice.size() != 5 or rerolled_dice.size() != 5:
		failures.append("Bar Dice resolve did not report final player dice.")
		return
	if JSON.stringify(kept_dice) == JSON.stringify(rerolled_dice):
		failures.append("Bar Dice keep/reroll selection did not change the final dice.")


func _bar_dice_resolve_with_reroll(game: GameModule, seed_text: String, reroll: Array) -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed_text)
	run_state.bankroll = 100000
	var environment := _surface_contract_environment()
	environment["game_states"] = {"bar_dice": game.generate_environment_state(run_state, environment, run_state.create_rng("bar_dice_keep_state"))}
	run_state.current_environment = environment.duplicate(true)
	var roll_command: Dictionary = game.surface_action_command("bar_dice_roll", 0, false, {}, run_state, run_state.current_environment)
	var ui: Dictionary = roll_command.get("ui_state", {})
	if not reroll.is_empty():
		ui["reroll"] = reroll
		var shake_command: Dictionary = game.surface_action_command("bar_dice_shake", 0, false, ui, run_state, run_state.current_environment)
		ui = shake_command.get("ui_state", ui)
	return game.resolve_with_context("roll", 10, run_state, run_state.current_environment, run_state.create_rng("bar_dice_keep_resolve"), ui)


func _check_bar_dice_patron_turn_determinism(game: GameModule, failures: Array) -> void:
	var first := _bar_dice_seeded_round_signature(game, "BAR-DICE-PATRON-DETERMINISM")
	var second := _bar_dice_seeded_round_signature(game, "BAR-DICE-PATRON-DETERMINISM")
	if JSON.stringify(first) != JSON.stringify(second):
		failures.append("Bar Dice patron turns did not resolve deterministically from the same seed.")
	var legs: Array = first.get("legs", [])
	if legs.size() < 2:
		failures.append("Bar Dice patron determinism fixture did not expose opponent legs.")
	for leg_value in legs:
		var leg: Dictionary = leg_value if typeof(leg_value) == TYPE_DICTIONARY else {}
		if (leg.get("dice", []) as Array).size() != 5:
			failures.append("Bar Dice patron leg did not expose the visible five-die roll.")
			break
		if str(leg.get("banter", "")).strip_edges().is_empty() or str(leg.get("personality", "")).strip_edges().is_empty():
			failures.append("Bar Dice patron leg did not include readable personality and banter.")
			break
		if int(leg.get("turn_wait_msec", -1)) != 0:
			failures.append("Bar Dice patron leg introduced a dead wait between opponent turns.")
			break


func _bar_dice_seeded_round_signature(game: GameModule, seed_text: String) -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed_text)
	run_state.bankroll = 100000
	var environment := _surface_contract_environment()
	environment["game_states"] = {"bar_dice": _bar_dice_state_for(game, run_state, environment, "ship_captain_crew", "standard", "pot_rake")}
	run_state.current_environment = environment.duplicate(true)
	var result := _bar_dice_play_round(game, run_state, run_state.create_rng("bar_dice_patron_turns"), "roll")
	return {
		"outcome": str(result.get("bar_dice_outcome", "")),
		"player_dice": result.get("bar_dice_player_dice", []),
		"house_dice": result.get("bar_dice_house_dice", []),
		"pot": int(result.get("bar_dice_pot", 0)),
		"carryover": int(result.get("bar_dice_carryover_pot", 0)),
		"legs": result.get("bar_dice_match_legs", []),
	}


func _check_bar_dice_match_and_bonuses(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("BAR-DICE-MATCH-BONUS")
	run_state.bankroll = 100000
	var environment := _surface_contract_environment()
	environment["game_states"] = {"bar_dice": _bar_dice_state_for(game, run_state, environment, "ship_captain_crew", "standard", "pot_rake")}
	run_state.current_environment = environment.duplicate(true)
	var result := _bar_dice_play_round(game, run_state, run_state.create_rng("bar_dice_match_bonus"), "roll")
	var legs: Array = result.get("bar_dice_match_legs", [])
	if legs.size() < 2:
		failures.append("Bar Dice table round did not resolve patron/house opponent seats.")
	var player_legs := int(result.get("bar_dice_player_legs", 0))
	var house_legs := int(result.get("bar_dice_house_legs", 0))
	var outcome := str(result.get("bar_dice_outcome", ""))
	if not ["win", "lose", "carry"].has(outcome):
		failures.append("Bar Dice table round reported an unknown outcome '%s'." % outcome)
	if outcome == "win" and player_legs != 1:
		failures.append("Bar Dice table win did not mark the player as the sole winning seat.")
	if outcome == "lose" and house_legs != 1:
		failures.append("Bar Dice table loss did not mark a non-player winning seat.")
	var reported_stake := int(result.get("bar_dice_stake", 0))
	if reported_stake <= 0 or int(result.get("bar_dice_side_bet", -1)) != 0:
		failures.append("Bar Dice result did not report stake and side-bet math.")
	if int(result.get("bar_dice_pot", 0)) < reported_stake * 2:
		failures.append("Bar Dice table round did not report a multi-seat pot.")
	if int(result.get("bar_dice_rake", -1)) < 0:
		failures.append("Bar Dice table round did not report non-negative rake.")
	var forced_state: Dictionary = run_state.current_environment.get("game_states", {}).get("bar_dice", {})
	if outcome == "carry" and int(forced_state.get("carryover_pot", 0)) <= 0:
		failures.append("Bar Dice carry result did not move the table pot into carryover.")
	_check_bar_dice_carryover_math(game, failures)
	var press_seed: RunState = RunStateScript.new()
	press_seed.start_new("BAR-DICE-PRESS-OFFER")
	press_seed.bankroll = 100000
	var press_environment := _surface_contract_environment()
	press_environment["game_states"] = {"bar_dice": _bar_dice_state_for(game, press_seed, press_environment, "ship_captain_crew", "friendly", "pot_rake")}
	press_seed.current_environment = press_environment.duplicate(true)
	var found_press := false
	var rng: RngStream = press_seed.create_rng("bar_dice_press_offer")
	for _i in range(160):
		var press_result := _bar_dice_play_round(game, press_seed, rng, "roll")
		var state: Dictionary = press_seed.current_environment.get("game_states", {}).get("bar_dice", {})
		var last_result: Dictionary = state.get("last_result", {})
		if bool((last_result.get("press_offer", {}) as Dictionary).get("available", false)):
			found_press = true
			var before := _run_state_result_snapshot(press_seed)
			var resolved_press := game.resolve_with_context("press", int(press_result.get("bar_dice_stake", 1)), press_seed, press_seed.current_environment, rng, {})
			_check_action_result_shape(resolved_press, "legal", failures)
			_check_action_result_application_contract(before, press_seed, resolved_press, "bar dice press result", failures)
			break
	if not found_press:
		failures.append("Bar Dice did not produce a press/double-up offer after repeated clean wins.")


func _check_bar_dice_carryover_math(game: GameModule, failures: Array) -> void:
	var carry_run: RunState = RunStateScript.new()
	carry_run.start_new("BAR-DICE-CARRYOVER-MATH")
	carry_run.bankroll = 1000000
	var environment := _surface_contract_environment()
	environment["game_states"] = {"bar_dice": _bar_dice_state_for(game, carry_run, environment, "ship_captain_crew", "standard", "pot_rake")}
	carry_run.current_environment = environment.duplicate(true)
	var rng: RngStream = carry_run.create_rng("bar_dice_carryover")
	var carry_result: Dictionary = {}
	for _attempt in range(260):
		var result := _bar_dice_play_round(game, carry_run, rng, "roll")
		if str(result.get("bar_dice_outcome", "")) == "carry":
			carry_result = result
			break
	if carry_result.is_empty():
		failures.append("Bar Dice carryover math fixture could not produce a carry result.")
		return
	var carry_state: Dictionary = (carry_run.current_environment.get("game_states", {}) as Dictionary).get("bar_dice", {})
	var carryover := int(carry_state.get("carryover_pot", 0))
	var carry_pot := int(carry_result.get("bar_dice_pot", 0))
	if carryover != carry_pot:
		failures.append("Bar Dice carryover pot did not equal the tied/no-qualifying round pot.")
	var next_result := _bar_dice_play_round(game, carry_run, rng, "roll")
	var next_stake := int(next_result.get("bar_dice_stake", 0))
	var next_game_states: Dictionary = carry_run.current_environment.get("game_states", {})
	var next_table: Dictionary = next_game_states.get("bar_dice", {})
	var next_last: Dictionary = next_table.get("last_result", {})
	var next_participants := int(next_last.get("participant_count", 0))
	var expected_next_pot := carryover + next_stake * next_participants
	if int(next_result.get("bar_dice_pot", 0)) != expected_next_pot:
		failures.append("Bar Dice next-round pot did not include carryover exactly (%d != %d)." % [int(next_result.get("bar_dice_pot", 0)), expected_next_pot])
	var next_state: Dictionary = (carry_run.current_environment.get("game_states", {}) as Dictionary).get("bar_dice", {})
	if str(next_result.get("bar_dice_outcome", "")) == "carry":
		if int(next_state.get("carryover_pot", 0)) != int(next_result.get("bar_dice_pot", 0)):
			failures.append("Bar Dice repeated carry did not roll the full next pot forward.")
	elif int(next_state.get("carryover_pot", -1)) != 0:
		failures.append("Bar Dice carryover pot did not clear after a non-carry round.")


func _check_bar_dice_stake_lifecycle(game: GameModule, failures: Array) -> void:
	var fixtures := {
		"win": 2,
		"lose": 10,
		"carry": 20,
	}
	for outcome_key in fixtures.keys():
		var target_outcome := str(outcome_key)
		var target_stake := int(fixtures.get(outcome_key, 10))
		var found_result: Dictionary = {}
		var found_before_bankroll := 0
		var found_after_bankroll := 0
		var run_state: RunState = RunStateScript.new()
		run_state.start_new("BAR-DICE-STAKE-LIFECYCLE-%s" % target_outcome)
		run_state.bankroll = 100000
		var environment := _surface_contract_environment()
		environment["game_states"] = {"bar_dice": _bar_dice_state_for(game, run_state, environment, "ship_captain_crew", "standard", "pot_rake")}
		run_state.current_environment = environment.duplicate(true)
		var rng: RngStream = run_state.create_rng("bar_dice_stake_lifecycle_%s" % target_outcome)
		for _attempt in range(360):
			var before_bankroll := run_state.bankroll
			var result := _bar_dice_play_round(game, run_state, rng, "roll", target_stake)
			if str(result.get("bar_dice_outcome", "")) != target_outcome:
				continue
			found_result = result
			found_before_bankroll = before_bankroll
			found_after_bankroll = run_state.bankroll
			break
		if found_result.is_empty():
			failures.append("Bar Dice stake lifecycle fixture could not find a %s result." % target_outcome)
			continue
		var stake := int(found_result.get("bar_dice_stake", 0))
		var participants := int(found_result.get("bar_dice_match_legs", []).size()) + 1
		var expected_min_pot := stake * participants
		var pot := int(found_result.get("bar_dice_pot", 0))
		if stake != target_stake:
			failures.append("Bar Dice %s lifecycle used stake %d instead of selected tier %d." % [target_outcome, stake, target_stake])
		if pot < expected_min_pot:
			failures.append("Bar Dice %s lifecycle pot %d was below stake x seats %d." % [target_outcome, pot, expected_min_pot])
		var bankroll_delta := int(found_result.get("bankroll_delta", 0))
		if found_after_bankroll - found_before_bankroll != bankroll_delta:
			failures.append("Bar Dice %s lifecycle bankroll changed %+d but result reported %+d." % [target_outcome, found_after_bankroll - found_before_bankroll, bankroll_delta])
		if target_outcome == "win":
			var gross_payout := int(found_result.get("bar_dice_gross_payout", found_result.get("bar_dice_payout", 0)))
			if gross_payout <= 0:
				gross_payout = int(found_result.get("bar_dice_pot", 0)) - int(found_result.get("bar_dice_rake", 0))
			if bankroll_delta != gross_payout - stake:
				failures.append("Bar Dice win lifecycle delta %+d did not equal gross payout %d minus stake %d." % [bankroll_delta, gross_payout, stake])
		elif bankroll_delta != -stake:
			failures.append("Bar Dice %s lifecycle should charge exactly the ante (%+d != -%d)." % [target_outcome, bankroll_delta, stake])
		if target_outcome == "carry":
			var table: Dictionary = (run_state.current_environment.get("game_states", {}) as Dictionary).get("bar_dice", {})
			if int(table.get("carryover_pot", 0)) != pot:
				failures.append("Bar Dice carry lifecycle did not store the full pot as carryover.")


func _check_bar_dice_cheat(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("BAR-DICE-CHEAT")
	run_state.bankroll = 100000
	var environment := _surface_contract_environment()
	environment["game_states"] = {"bar_dice": game.generate_environment_state(run_state, environment, run_state.create_rng("bar_dice_cheat_state"))}
	run_state.current_environment = environment.duplicate(true)
	var before := _run_state_result_snapshot(run_state)
	var roll_command: Dictionary = game.surface_action_command("bar_dice_roll", 0, false, {}, run_state, run_state.current_environment)
	var ui: Dictionary = _bar_dice_controlled_roll_timed_ui(game, run_state, roll_command.get("ui_state", {}), 0)
	var loaded_result := game.resolve_with_context("loaded_toss", 10, run_state, run_state.current_environment, run_state.create_rng("bar_dice_cheat_resolve"), ui)
	_check_action_result_shape(loaded_result, "cheat", failures)
	if int(loaded_result.get("suspicion_delta", 0)) <= 0:
		failures.append("Bar Dice loaded toss did not raise suspicion heat.")
	if not bool(loaded_result.get("bar_dice_loaded", false)) or int(loaded_result.get("bar_dice_loaded_value", 0)) < 1:
		failures.append("Bar Dice loaded toss did not record the rigged die value.")
	if str(loaded_result.get("skill_grade", "")) != "perfect" or str(loaded_result.get("skill_outcome", "")) != "controlled_roll_perfect":
		failures.append("Bar Dice controlled roll did not report the perfect graded skill outcome.")
	if not bool(loaded_result.get("bar_dice_controlled_roll_applied", false)):
		failures.append("Bar Dice perfect controlled roll did not apply the desired die face.")
	if typeof(loaded_result.get("skill_story_context", {})) != TYPE_DICTIONARY or int((loaded_result.get("skill_story_context", {}) as Dictionary).get("skill_margin_msec", 999)) != 0:
		failures.append("Bar Dice controlled roll did not expose timing margin in skill_story_context.")
	_check_action_result_application_contract(before, run_state, loaded_result, "bar dice loaded result", failures)
	var direct_state: RunState = RunStateScript.new()
	direct_state.start_new("BAR-DICE-CHEAT-DIRECT")
	direct_state.bankroll = 100000
	var direct_environment := _surface_contract_environment()
	direct_environment["game_states"] = {"bar_dice": game.generate_environment_state(direct_state, direct_environment, direct_state.create_rng("bar_dice_direct_state"))}
	direct_state.current_environment = direct_environment.duplicate(true)
	var direct_roll: Dictionary = game.surface_action_command("bar_dice_roll", 0, false, {}, direct_state, direct_state.current_environment)
	var direct_result := game.resolve_with_context("loaded_toss", 10, direct_state, direct_state.current_environment, direct_state.create_rng("bar_dice_direct_resolve"), direct_roll.get("ui_state", {}))
	if bool(direct_result.get("bar_dice_controlled_roll_applied", false)) or str(direct_result.get("skill_grade", "")) != "miss":
		failures.append("Bar Dice loaded_toss without RELEASE granted an ungraded controlled-roll payoff.")
	var deterministic_a: RunState = RunStateScript.new()
	deterministic_a.start_new("BAR-DICE-CONTROL-DETERMINISTIC")
	deterministic_a.bankroll = 100000
	var deterministic_env_a := _surface_contract_environment()
	deterministic_env_a["game_states"] = {"bar_dice": game.generate_environment_state(deterministic_a, deterministic_env_a, deterministic_a.create_rng("bar_dice_det_state"))}
	deterministic_a.current_environment = deterministic_env_a.duplicate(true)
	var deterministic_b: RunState = RunStateScript.new()
	deterministic_b.start_new("BAR-DICE-CONTROL-DETERMINISTIC")
	deterministic_b.bankroll = 100000
	var deterministic_env_b := _surface_contract_environment()
	deterministic_env_b["game_states"] = {"bar_dice": game.generate_environment_state(deterministic_b, deterministic_env_b, deterministic_b.create_rng("bar_dice_det_state"))}
	deterministic_b.current_environment = deterministic_env_b.duplicate(true)
	var det_roll_a := game.surface_action_command("bar_dice_roll", 0, false, {"surface_time_msec": 20000}, deterministic_a, deterministic_a.current_environment)
	var det_roll_b := game.surface_action_command("bar_dice_roll", 0, false, {"surface_time_msec": 20000}, deterministic_b, deterministic_b.current_environment)
	var det_ui_a: Dictionary = _bar_dice_controlled_roll_timed_ui(game, deterministic_a, det_roll_a.get("ui_state", {"surface_time_msec": 20000}), 0)
	var det_ui_b: Dictionary = _bar_dice_controlled_roll_timed_ui(game, deterministic_b, det_roll_b.get("ui_state", {"surface_time_msec": 20000}), 0)
	if JSON.stringify(det_ui_a.get("controlled_roll", {})) != JSON.stringify(det_ui_b.get("controlled_roll", {})):
		failures.append("Bar Dice controlled-roll challenge did not start deterministically from seeded input.")
	var round_trip_state: Dictionary = JSON.parse_string(JSON.stringify(det_ui_a))
	var round_trip_surface := game.surface_state(deterministic_a, deterministic_a.current_environment, round_trip_state)
	if typeof(round_trip_surface.get("controlled_roll", {})) != TYPE_DICTIONARY or (round_trip_surface.get("controlled_roll", {}) as Dictionary).is_empty():
		failures.append("Bar Dice controlled-roll UI state did not survive save/load-style serialization mid-challenge.")
	var palm_state: RunState = RunStateScript.new()
	palm_state.start_new("BAR-DICE-PALM-CHEAT")
	palm_state.bankroll = 100000
	var palm_environment := _surface_contract_environment()
	palm_environment["game_states"] = {"bar_dice": game.generate_environment_state(palm_state, palm_environment, palm_state.create_rng("bar_dice_palm_state"))}
	palm_state.current_environment = palm_environment.duplicate(true)
	var palm_roll: Dictionary = game.surface_action_command("bar_dice_roll", 0, false, {}, palm_state, palm_state.current_environment)
	var palm_ui: Dictionary = _bar_dice_palmed_swap_timed_ui(game, palm_state, palm_roll.get("ui_state", {}), 0)
	var palm_result := game.resolve_with_context("palmed_swap", 10, palm_state, palm_state.current_environment, palm_state.create_rng("bar_dice_palm_resolve"), palm_ui)
	_check_action_result_shape(palm_result, "cheat", failures)
	if not bool(palm_result.get("bar_dice_palmed", false)) or not bool(palm_result.get("bar_dice_palmed_swap_applied", false)) or str(palm_result.get("skill_grade", "")) != "perfect" or int(palm_result.get("suspicion_delta", 0)) <= 0:
		failures.append("Bar Dice palmed swap did not grade perfect input, improve a die, and add suspicion heat.")
	var direct_palm_state: RunState = RunStateScript.new()
	direct_palm_state.start_new("BAR-DICE-PALM-DIRECT")
	direct_palm_state.bankroll = 100000
	var direct_palm_environment := _surface_contract_environment()
	direct_palm_environment["game_states"] = {"bar_dice": game.generate_environment_state(direct_palm_state, direct_palm_environment, direct_palm_state.create_rng("bar_dice_palm_direct_state"))}
	direct_palm_state.current_environment = direct_palm_environment.duplicate(true)
	var direct_palm_roll := game.surface_action_command("bar_dice_roll", 0, false, {}, direct_palm_state, direct_palm_state.current_environment)
	var direct_palm_result := game.resolve_with_context("palmed_swap", 10, direct_palm_state, direct_palm_state.current_environment, direct_palm_state.create_rng("bar_dice_palm_direct_resolve"), direct_palm_roll.get("ui_state", {}))
	if str(direct_palm_result.get("skill_grade", "")) != "miss" or bool(direct_palm_result.get("bar_dice_palmed_swap_applied", true)) or str(direct_palm_result.get("message", "")).to_lower().find("no die") < 0:
		failures.append("Bar Dice direct palmed_swap resolve granted an ungraded die change or lacked readable failure feedback.")
	var palm_deterministic_a := _bar_dice_palmed_swap_fixture(game, "BAR-DICE-PALM-DETERMINISTIC")
	var palm_deterministic_b := _bar_dice_palmed_swap_fixture(game, "BAR-DICE-PALM-DETERMINISTIC")
	if JSON.stringify(palm_deterministic_a.get("challenge", {})) != JSON.stringify(palm_deterministic_b.get("challenge", {})):
		failures.append("Bar Dice palmed-swap challenge was not deterministic for the same seed and input.")
	var palm_round_trip: Dictionary = JSON.parse_string(JSON.stringify((palm_deterministic_a.get("command", {}) as Dictionary).get("ui_state", {})))
	var palm_round_trip_run := palm_deterministic_a.get("run_state", null) as RunState
	var palm_round_trip_surface := game.surface_state(palm_round_trip_run, palm_round_trip_run.current_environment, palm_round_trip)
	if typeof(palm_round_trip_surface.get("palmed_swap_challenge", {})) != TYPE_DICTIONARY or (palm_round_trip_surface.get("palmed_swap_challenge", {}) as Dictionary).is_empty():
		failures.append("Bar Dice palmed-swap UI state did not survive save/load-style serialization mid-challenge.")
	var palm_sober := _bar_dice_palmed_swap_fixture(game, "BAR-DICE-PALM-MODIFIERS")
	var palm_drunk := _bar_dice_palmed_swap_fixture(game, "BAR-DICE-PALM-MODIFIERS", 85)
	var palm_item := _bar_dice_palmed_swap_fixture(game, "BAR-DICE-PALM-MODIFIERS", 0, "dice_calipers")
	var palm_sober_challenge: Dictionary = palm_sober.get("challenge", {})
	var palm_drunk_challenge: Dictionary = palm_drunk.get("challenge", {})
	var palm_item_challenge: Dictionary = palm_item.get("challenge", {})
	if int(palm_drunk_challenge.get("perfect_window_msec", 999)) >= int(palm_sober_challenge.get("perfect_window_msec", 0)):
		failures.append("Bar Dice alcohol did not narrow the palmed-swap precision window.")
	if int(palm_item_challenge.get("perfect_window_msec", 0)) <= int(palm_sober_challenge.get("perfect_window_msec", 0)) or int(palm_item_challenge.get("base_heat", 999)) >= int(palm_sober_challenge.get("base_heat", 0)):
		failures.append("Bar Dice calipers did not widen the palmed-swap window and reduce base heat.")
	var palm_blown_fixture := _bar_dice_palmed_swap_fixture(game, "BAR-DICE-PALM-BLOWN")
	var palm_blown_run := palm_blown_fixture.get("run_state", null) as RunState
	var palm_blown_command: Dictionary = palm_blown_fixture.get("command", {})
	var palm_blown_ui: Dictionary = palm_blown_command.get("ui_state", {})
	var palm_blown_challenge: Dictionary = palm_blown_ui.get("palmed_swap_challenge", {})
	palm_blown_ui["surface_time_msec"] = int(palm_blown_challenge.get("target_msec", 0)) + int(palm_blown_challenge.get("meter_period_msec", 1500)) / 2
	var palm_blown_lock := game.surface_action_command("bar_dice_palm", 0, false, palm_blown_ui, palm_blown_run, palm_blown_run.current_environment)
	var palm_blown_result := game.resolve_with_context("palmed_swap", 10, palm_blown_run, palm_blown_run.current_environment, palm_blown_run.create_rng("bar_dice_palm_blown_resolve"), palm_blown_lock.get("ui_state", palm_blown_ui))
	if str(palm_blown_result.get("skill_grade", "")) != "blown" or bool(palm_blown_result.get("bar_dice_palmed_swap_applied", true)) or str(palm_blown_result.get("message", "")).to_lower().find("no die") < 0:
		failures.append("Bar Dice blown palmed swap did not leave dice unchanged with distinct failure feedback.")
	var honest_wins := _bar_dice_win_rate(game, "roll", "BAR-DICE-HONEST")
	var loaded_wins := _bar_dice_win_rate(game, "loaded_toss", "BAR-DICE-LOADED")
	if loaded_wins <= honest_wins + 0.05:
		failures.append("Bar Dice loaded die did not meaningfully improve win odds (honest=%.3f loaded=%.3f)." % [honest_wins, loaded_wins])
	var palmed_wins := _bar_dice_win_rate(game, "palmed_swap", "BAR-DICE-PALMED")
	if palmed_wins <= honest_wins + 0.05:
		failures.append("Bar Dice palmed swap did not meaningfully improve win odds (honest=%.3f palmed=%.3f)." % [honest_wins, palmed_wins])


func _bar_dice_win_rate(game: GameModule, action_id: String, seed_text: String) -> float:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed_text)
	run_state.bankroll = 100000000
	var environment := _surface_contract_environment()
	environment["game_states"] = {"bar_dice": game.generate_environment_state(run_state, environment, run_state.create_rng("bar_dice_winrate_state"))}
	run_state.current_environment = environment.duplicate(true)
	var rng: RngStream = run_state.create_rng("bar_dice_winrate")
	var rounds := 4000
	var wins := 0
	for _round in range(rounds):
		run_state.suspicion = {"level": 0, "cues": [], "local_levels": {}}
		var result := _bar_dice_play_round(game, run_state, rng, action_id)
		if str(result.get("bar_dice_outcome", "")) == "win":
			wins += 1
	return float(wins) / float(rounds)


func _check_bar_dice_item_luck_alcohol(game: GameModule, failures: Array) -> void:
	var sober: RunState = RunStateScript.new()
	sober.start_new("BAR-DICE-ALCOHOL-SOBER")
	sober.bankroll = 100000
	var sober_environment := _surface_contract_environment()
	sober_environment["security_profile"] = {"pit_boss": {"enabled": true, "cycle_length": 2, "watched_turns": 1, "cheat_heat_bonus": 20}}
	sober_environment["game_states"] = {"bar_dice": _bar_dice_state_for(game, sober, sober_environment, "ship_captain_crew", "standard", "pot_rake")}
	sober.current_environment = sober_environment.duplicate(true)
	_xgame_apply_watched_spatial_state(sober, "bar_dice", true)
	var sober_roll: Dictionary = game.surface_action_command("bar_dice_roll", 0, false, {}, sober, sober.current_environment)
	var sober_ui: Dictionary = _bar_dice_controlled_roll_timed_ui(game, sober, sober_roll.get("ui_state", {}), 0)
	var sober_result := game.resolve_with_context("loaded_toss", 10, sober, sober.current_environment, sober.create_rng("bar_dice_sober"), sober_ui)
	var drunk: RunState = RunStateScript.new()
	drunk.start_new("BAR-DICE-ALCOHOL-SOBER")
	drunk.bankroll = 100000
	drunk.drunk_level = 85
	var drunk_environment := _surface_contract_environment()
	drunk_environment["security_profile"] = sober_environment["security_profile"]
	drunk_environment["game_states"] = {"bar_dice": _bar_dice_state_for(game, drunk, drunk_environment, "ship_captain_crew", "standard", "pot_rake")}
	drunk.current_environment = drunk_environment.duplicate(true)
	_xgame_apply_watched_spatial_state(drunk, "bar_dice", true)
	var drunk_roll: Dictionary = game.surface_action_command("bar_dice_roll", 0, false, {}, drunk, drunk.current_environment)
	var drunk_ui: Dictionary = _bar_dice_controlled_roll_timed_ui(game, drunk, drunk_roll.get("ui_state", {}), 0)
	var drunk_result := game.resolve_with_context("loaded_toss", 10, drunk, drunk.current_environment, drunk.create_rng("bar_dice_sober"), drunk_ui)
	if int(drunk_result.get("suspicion_delta", 0)) <= int(sober_result.get("suspicion_delta", 0)):
		failures.append("Bar Dice cheat heat did not respond to alcohol pressure.")
	var low_snitch: RunState = RunStateScript.new()
	low_snitch.start_new("BAR-DICE-SNITCH-LOW")
	low_snitch.bankroll = 100000
	var low_environment := _surface_contract_environment()
	var low_state := _bar_dice_state_for(game, low_snitch, low_environment, "ship_captain_crew", "standard", "pot_rake")
	low_state["patrons"] = [{"id": "quiet_rail", "name": "Quiet Rail", "watching": false, "snitch_risk": 0, "rapport": 60}]
	low_environment["game_states"] = {"bar_dice": low_state}
	low_snitch.current_environment = low_environment.duplicate(true)
	var low_roll: Dictionary = game.surface_action_command("bar_dice_roll", 0, false, {}, low_snitch, low_snitch.current_environment)
	var low_ui: Dictionary = _bar_dice_controlled_roll_timed_ui(game, low_snitch, low_roll.get("ui_state", {}), 999)
	var low_result := game.resolve_with_context("loaded_toss", 10, low_snitch, low_snitch.current_environment, low_snitch.create_rng("bar_dice_snitch_low"), low_ui)
	var high_snitch: RunState = RunStateScript.new()
	high_snitch.start_new("BAR-DICE-SNITCH-HIGH")
	high_snitch.bankroll = 100000
	var high_environment := _surface_contract_environment()
	var high_state := _bar_dice_state_for(game, high_snitch, high_environment, "ship_captain_crew", "standard", "pot_rake")
	high_state["patrons"] = [
		{"id": "snitch_0", "name": "Sharp Rail", "watching": true, "snitch_risk": 60, "rapport": 25},
		{"id": "snitch_1", "name": "Nosy Rail", "watching": true, "snitch_risk": 60, "rapport": 25},
		{"id": "snitch_2", "name": "Loud Rail", "watching": true, "snitch_risk": 60, "rapport": 25},
	]
	high_environment["game_states"] = {"bar_dice": high_state}
	high_snitch.current_environment = high_environment.duplicate(true)
	var high_roll: Dictionary = game.surface_action_command("bar_dice_roll", 0, false, {}, high_snitch, high_snitch.current_environment)
	var high_ui: Dictionary = _bar_dice_controlled_roll_timed_ui(game, high_snitch, high_roll.get("ui_state", {}), 999)
	var high_result := game.resolve_with_context("loaded_toss", 10, high_snitch, high_snitch.current_environment, high_snitch.create_rng("bar_dice_snitch_high"), high_ui)
	if int(high_result.get("suspicion_delta", 0)) <= int(low_result.get("suspicion_delta", 0)) or int(high_result.get("bar_dice_patron_snitch_heat_bonus", 0)) <= int(low_result.get("bar_dice_patron_snitch_heat_bonus", 0)):
		failures.append("Bar Dice patron snitch pressure did not raise controlled-roll heat.")
	var luck_low := _bar_dice_win_rate_with_luck(game, "BAR-DICE-LUCK-LOW", 0)
	var luck_high := _bar_dice_win_rate_with_luck(game, "BAR-DICE-LUCK-HIGH", 8)
	if luck_high <= luck_low:
		failures.append("Bar Dice match odds did not respond to RunState luck (low=%.3f high=%.3f)." % [luck_low, luck_high])
	var watched_heat := int(sober_result.get("suspicion_delta", 0))
	if watched_heat < 20:
		failures.append("Bar Dice cheat heat did not include pit-boss/security watch pressure.")


func _bar_dice_win_rate_with_luck(game: GameModule, seed_text: String, luck: int) -> float:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed_text)
	run_state.bankroll = 100000000
	run_state.baseline_luck = luck
	var environment := _surface_contract_environment()
	environment["game_states"] = {"bar_dice": _bar_dice_state_for(game, run_state, environment, "ship_captain_crew", "standard", "pot_rake")}
	run_state.current_environment = environment.duplicate(true)
	var rng: RngStream = run_state.create_rng("bar_dice_luck_rate")
	var rounds := 1200
	var wins := 0
	for _round in range(rounds):
		var result := _bar_dice_play_round(game, run_state, rng, "roll")
		if str(result.get("bar_dice_outcome", "")) == "win":
			wins += 1
	return float(wins) / float(rounds)


func _check_bar_dice_edge_band(game: GameModule, _library: ContentLibrary, failures: Array) -> void:
	var tiers := ["friendly", "standard", "sharp"]
	for tier in tiers:
		_check_bar_dice_edge_for(game, "ship_captain_crew", str(tier), failures)


func _check_bar_dice_edge_for(game: GameModule, ruleset: String, tier: String, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("BAR-DICE-MC-EDGE-%s-%s" % [ruleset, tier])
	run_state.bankroll = 100000000
	var environment := _surface_contract_environment()
	environment["game_states"] = {"bar_dice": _bar_dice_state_for(game, run_state, environment, ruleset, tier, "pot_rake")}
	run_state.current_environment = environment.duplicate(true)
	var rng: RngStream = run_state.create_rng("bar_dice_edge")
	var rounds := 1000
	var staked := 0
	var net := 0
	for _round in range(rounds):
		var before := run_state.bankroll
		var result := _bar_dice_play_round(game, run_state, rng, "roll")
		staked += int(result.get("bar_dice_stake", 0)) + int(result.get("bar_dice_side_bet", 0))
		net += run_state.bankroll - before
	var edge := -float(net) / float(staked)
	print("BAR_DICE %s/%s house edge over %d rounds = %.4f" % [ruleset, tier, rounds, edge])
	var min_edge := -0.02
	var max_edge := 0.20 if tier == "sharp" else 0.16
	if edge < min_edge or edge > max_edge:
		failures.append("Bar Dice %s/%s house edge %.4f fell outside the sane band." % [ruleset, tier, edge])


func _check_bar_dice_save_load(game: GameModule, failures: Array) -> void:
	_check_bar_dice_save_load_mid_round(game, failures)
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("BAR-DICE-SAVE-LOAD")
	run_state.bankroll = 100000
	var environment := _surface_contract_environment()
	environment["game_states"] = {"bar_dice": game.generate_environment_state(run_state, environment, run_state.create_rng("bar_dice_save_load_state"))}
	run_state.current_environment = environment.duplicate(true)
	var result := _bar_dice_play_round(game, run_state, run_state.create_rng("bar_dice_save_load_round"), "roll")
	if not bool(result.get("ok", false)):
		failures.append("Bar Dice save/load fixture did not resolve a round.")
	var original_state: Dictionary = (run_state.current_environment.get("game_states", {}) as Dictionary).get("bar_dice", {})
	var restored: RunState = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	var restored_state: Dictionary = (restored.current_environment.get("game_states", {}) as Dictionary).get("bar_dice", {})
	if JSON.stringify(original_state) != JSON.stringify(restored_state):
		failures.append("Bar Dice table state did not survive RunState save/load round-trip.")
	for required_key in ["ruleset_family", "available_variants", "hosted_payout_percent", "carryover_pot", "patrons", "dealer_profile", "last_result"]:
		if not restored_state.has(required_key):
			failures.append("Bar Dice restored table state is missing %s." % required_key)


func _check_bar_dice_save_load_mid_round(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("BAR-DICE-SAVE-MID-ROUND")
	run_state.bankroll = 100000
	var environment := _surface_contract_environment()
	environment["game_states"] = {"bar_dice": game.generate_environment_state(run_state, environment, run_state.create_rng("bar_dice_mid_round_state"))}
	run_state.current_environment = environment.duplicate(true)
	var roll_command: Dictionary = game.surface_action_command("bar_dice_roll", 0, false, {}, run_state, run_state.current_environment)
	var ui: Dictionary = roll_command.get("ui_state", {})
	var surface := game.surface_state(run_state, run_state.current_environment, ui)
	var suggested: Array = surface.get("suggested_reroll", [])
	if not suggested.is_empty():
		ui["reroll"] = [int(suggested[0])]
	ui["surface_time_msec"] = 27000
	var restored: RunState = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	var parsed_ui: Variant = JSON.parse_string(JSON.stringify(ui))
	var restored_ui: Dictionary = parsed_ui if typeof(parsed_ui) == TYPE_DICTIONARY else {}
	var restored_surface := game.surface_state(restored, restored.current_environment, restored_ui)
	if str(restored_surface.get("phase", "")) != "select":
		failures.append("Bar Dice save/load mid-round did not restore the select phase.")
	if JSON.stringify(restored_surface.get("player", [])) != JSON.stringify(ui.get("dice", [])):
		failures.append("Bar Dice save/load mid-round did not preserve visible player dice.")
	if JSON.stringify(restored_surface.get("reroll", [])) != JSON.stringify(ui.get("reroll", [])):
		failures.append("Bar Dice save/load mid-round did not preserve reroll marks.")
	var result := game.resolve_with_context("roll", 10, restored, restored.current_environment, restored.create_rng("bar_dice_mid_round_resolve"), restored_ui)
	if not bool(result.get("ok", false)) or (result.get("bar_dice_player_dice", []) as Array).size() != 5:
		failures.append("Bar Dice restored mid-round state could not resolve a valid table round.")


func _bar_dice_play_round(game: GameModule, run_state: RunState, rng: RngStream, action_id: String, stake: int = 10) -> Dictionary:
	var environment: Dictionary = run_state.current_environment
	var initial_ui := _bar_dice_stake_ui(run_state, stake)
	var roll_command: Dictionary = game.surface_action_command("bar_dice_roll", 0, false, initial_ui, run_state, environment)
	var ui: Dictionary = roll_command.get("ui_state", {})
	while int(ui.get("shake_number", 0)) < 3:
		var dice: Array = ui.get("dice", []) if typeof(ui.get("dice", [])) == TYPE_ARRAY else []
		if dice.size() != 5:
			break
		var suggested: Array = game.call("_suggested_reroll_for_ruleset", dice, "ship_captain_crew")
		if suggested.is_empty():
			break
		ui["reroll"] = suggested
		var shake_command: Dictionary = game.surface_action_command("bar_dice_shake", 0, false, ui, run_state, environment)
		ui = shake_command.get("ui_state", ui)
	if action_id == "loaded_toss":
		ui = _bar_dice_controlled_roll_timed_ui(game, run_state, ui, 0)
	elif action_id == "palmed_swap":
		ui = _bar_dice_palmed_swap_timed_ui(game, run_state, ui, 0)
	return game.resolve_with_context(action_id, stake, run_state, environment, rng, ui)


func _bar_dice_stake_ui(run_state: RunState, stake: int) -> Dictionary:
	var game_states: Dictionary = run_state.current_environment.get("game_states", {}) if typeof(run_state.current_environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var state: Dictionary = game_states.get("bar_dice", {}) if typeof(game_states.get("bar_dice", {})) == TYPE_DICTIONARY else {}
	var ladder: Array = []
	if typeof(state.get("stake_ladder", [])) == TYPE_ARRAY:
		for value in state.get("stake_ladder", []):
			ladder.append(int(value))
	var selected_index := int(state.get("selected_stake_index", 0))
	for index in range(ladder.size()):
		if int(ladder[index]) == stake:
			selected_index = index
			break
	return {"selected_stake_index": selected_index}


func _bar_dice_controlled_roll_timed_ui(game: GameModule, run_state: RunState, base_ui: Dictionary, margin_msec: int = 0) -> Dictionary:
	var ui: Dictionary = base_ui.duplicate(true)
	ui["surface_time_msec"] = int(ui.get("surface_time_msec", 14000))
	var load_command: Dictionary = game.surface_action_command("bar_dice_load", 0, false, ui, run_state, run_state.current_environment)
	var load_ui: Dictionary = load_command.get("ui_state", ui)
	var challenge: Dictionary = load_ui.get("controlled_roll", {}) if typeof(load_ui.get("controlled_roll", {})) == TYPE_DICTIONARY else {}
	load_ui["controlled_roll_input_msec"] = int(challenge.get("target_msec", int(load_ui.get("surface_time_msec", 14000)))) + margin_msec
	var release_command: Dictionary = game.surface_action_command("bar_dice_release", 0, false, load_ui, run_state, run_state.current_environment)
	return release_command.get("ui_state", load_ui)


func _bar_dice_palmed_swap_timed_ui(game: GameModule, run_state: RunState, base_ui: Dictionary, margin_msec: int = 0) -> Dictionary:
	var ui: Dictionary = base_ui.duplicate(true)
	ui["surface_time_msec"] = int(ui.get("surface_time_msec", 18000))
	var palm_command: Dictionary = game.surface_action_command("bar_dice_palm", 0, false, ui, run_state, run_state.current_environment)
	var palm_ui: Dictionary = palm_command.get("ui_state", ui)
	var challenge: Dictionary = palm_ui.get("palmed_swap_challenge", {}) if typeof(palm_ui.get("palmed_swap_challenge", {})) == TYPE_DICTIONARY else {}
	palm_ui["surface_time_msec"] = int(challenge.get("target_msec", int(palm_ui.get("surface_time_msec", 18000)))) + margin_msec
	var lock_command: Dictionary = game.surface_action_command("bar_dice_palm", 0, false, palm_ui, run_state, run_state.current_environment)
	return lock_command.get("ui_state", palm_ui)


func _bar_dice_palmed_swap_fixture(game: GameModule, seed_text: String, drunk_level: int = 0, item_id: String = "") -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed_text)
	run_state.bankroll = 100000
	run_state.drunk_level = drunk_level
	if not item_id.is_empty():
		run_state.add_item(item_id)
	var environment := _surface_contract_environment()
	environment["game_states"] = {"bar_dice": game.generate_environment_state(run_state, environment, run_state.create_rng("bar_dice_palmed_fixture_state"))}
	run_state.current_environment = environment.duplicate(true)
	var roll_command := game.surface_action_command("bar_dice_roll", 0, false, {"surface_time_msec": 22000}, run_state, run_state.current_environment)
	var palm_command := game.surface_action_command("bar_dice_palm", 0, false, roll_command.get("ui_state", {}), run_state, run_state.current_environment)
	var palm_ui: Dictionary = palm_command.get("ui_state", {})
	return {"run_state": run_state, "environment": environment, "command": palm_command, "challenge": palm_ui.get("palmed_swap_challenge", {})}


func _bar_dice_state_for(game: GameModule, run_state: RunState, environment: Dictionary, ruleset: String, tier: String, bonus_mode: String) -> Dictionary:
	var state: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("bar_dice_forced_%s_%s_%s" % [ruleset, tier, bonus_mode]))
	state["ruleset_family"] = "ship_captain_crew"
	state["ruleset_label"] = "Ship, Captain, Crew"
	state["edge_tier"] = tier
	state["edge_label"] = {
		"friendly": "Friendly Rake",
		"standard": "House Rake",
		"sharp": "Sharp Rake",
	}.get(tier, "House Rack")
	state["rake_percent"] = {
		"friendly": 4,
		"standard": 7,
		"sharp": 10,
	}.get(tier, 7)
	state["hosted_payout_percent"] = {
		"friendly": 68,
		"standard": 66,
		"sharp": 70,
	}.get(tier, 66)
	state["bonus_mode"] = "pot_rake"
	state["bonus_label"] = "Carryover Pot"
	state["carryover_pot"] = 0
	state["stake_ladder"] = [2, 5, 10, 20, 40]
	state["selected_stake_index"] = 2
	return state


