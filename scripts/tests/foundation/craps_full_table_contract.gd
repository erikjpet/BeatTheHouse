extends SceneTree

const CrapsGameScript := preload("res://scripts/games/craps.gd")
const CrapsRulesScript := preload("res://scripts/games/craps/craps_rules.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const GameSurfaceCanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var definition := _craps_definition()
	if definition.is_empty():
		_fail(["Craps definition could not be loaded."])
		return
	var game: GameModule = CrapsGameScript.new()
	game.setup(definition)
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("CRAPS-FULL-TABLE-CONTRACT")
	run_state.bankroll = 1000
	run_state.grand_casino_chips = 1000
	var environment := _environment(false)
	var table := game.generate_environment_state(run_state, environment, run_state.create_rng("craps_full_table"))
	environment["game_states"] = {"craps": table}
	run_state.current_environment = environment
	var surface := game.surface_state(run_state, environment, {})
	if bool(surface.get("can_roll", true)) or not bool(surface.get("can_pass_dice", false)):
		failures.append("A player could shoot the come-out without a line bet, or could not pass the dice.")
	var target_ids := _target_ids(surface.get("bet_targets", []))
	for target_id in ["pass_line", "dont_pass", "come", "dont_come", "field", "buy_4", "lay_10", "hard_8", "horn", "ce", "world", "any_seven"]:
		if not target_ids.has(target_id):
			failures.append("Missing full-table target %s." % target_id)
	if str(surface.get("surface_template", "")) != "shared_table_game_v1" or _array(surface.get("patrons", [])).size() != 5:
		failures.append("Casino Craps did not use the shared living-table cast.")
	_check_selectable_targets(game, run_state, environment, surface, "casino come-out", failures)
	var pass_index := target_ids.find("pass_line")
	var first_line_command := game.surface_action_command("craps_bet", pass_index, false, {"selected_chip": 5}, run_state, environment)
	var second_line_command := game.surface_action_command("craps_bet", pass_index, false, _dict(first_line_command.get("ui_state", {})), run_state, environment)
	if int(_dict(_dict(second_line_command.get("ui_state", {})).get("craps_pending_bets", {})).get("pass_line", 0)) != 10:
		failures.append("Pass Line rejected a second chip before the come-out roll.")
	var pass_environment := _environment(false)
	var pass_table := game.generate_environment_state(run_state, pass_environment, run_state.create_rng("craps_pass_dice"))
	pass_environment["game_states"] = {"craps": pass_table}
	run_state.current_environment = pass_environment
	var pass_command := game.surface_action_command("craps_pass_dice", 0, false, {}, run_state, pass_environment)
	var pass_result := game.resolve_with_context(str(pass_command.get("action_id", "")), 0, run_state, pass_environment, run_state.create_rng("craps_pass_dice_resolve"), _dict(pass_command.get("ui_state", {})))
	if not bool(pass_result.get("ok", false)) or str(_dict(pass_result.get("craps_shooter", {})).get("id", "player")) == "player" or int(pass_result.get("bankroll_delta", -1)) != 0:
		failures.append("Passing the come-out dice did not rotate clockwise without touching funds.")
	run_state.current_environment = environment
	var odds_table := table.duplicate(true)
	odds_table["point"] = 6
	odds_table["working_bets"] = {"pass_line": 10, "dont_pass": 10, "pass_odds": 0, "dont_pass_odds": 0, "come": {"5": 10}, "dont_come": {"9": 10}, "come_odds": {}, "dont_come_odds": {}, "place": {}, "buy": {}, "lay": {}, "hardways": {}, "big": {}, "working_on_come_out": false}
	environment["game_states"] = {"craps": odds_table}
	var point_surface := game.surface_state(run_state, environment, {"craps_bet_page": "odds", "selected_chip": 5})
	for odds_id in ["pass_odds", "dont_pass_odds", "come_odds_5", "dont_come_odds_9"]:
		if not _target_ids(point_surface.get("bet_targets", [])).has(odds_id):
			failures.append("Missing point-on odds target %s." % odds_id)
	_check_selectable_targets(game, run_state, environment, point_surface, "casino point-on", failures)
	environment["game_states"] = {"craps": table}

	var street_environment := _environment(true)
	var street_table := game.generate_environment_state(run_state, street_environment, run_state.create_rng("craps_street_group"))
	street_environment["game_states"] = {"craps": street_table}
	var street_surface := game.surface_state(run_state, street_environment, {"craps_bet_page": "props"})
	if _array(street_surface.get("patrons", [])).size() != 6 or str(street_surface.get("currency", "")) != "cash":
		failures.append("Street Craps did not retain its six-person cash-circle identity.")
	for target_value in _array(street_surface.get("bet_targets", [])):
		if typeof(target_value) == TYPE_DICTIONARY:
			var target_rect: Rect2 = (target_value as Dictionary).get("rect", Rect2())
			if target_rect.end.x > 620.0:
				failures.append("Street wager %s intrudes into the cash/history rail." % str((target_value as Dictionary).get("id", "unknown")))
				break

	table["point"] = 6
	table["shooter_index"] = 0
	environment["game_states"] = {"craps": table}
	run_state.current_environment = environment
	var seven_result := game.resolve_with_context("roll_craps", 0, run_state, run_state.current_environment, _rng_for_total(_dict(table.get("rules", {})), 7), {})
	if str(_dict(seven_result.get("craps_table_talk_request", {})).get("reaction", "")) != "seven_out_player" or str(_dict(seven_result.get("craps_shooter", {})).get("id", "player")) == "player":
		failures.append("Seven-out did not blame the player and rotate the shooter.")
	if _array(seven_result.get("craps_npc_bets", [])).size() != 5:
		failures.append("NPC wagers were not visible on the resolved casino throw.")

	var canvas: Control = GameSurfaceCanvasScript.new()
	canvas.size = Vector2(900, 474)
	root.add_child(canvas)
	canvas.call("set_game_module", game)
	for page in ["line", "numbers", "props", "odds"]:
		var page_surface := game.surface_state(run_state, run_state.current_environment, {"craps_bet_page": page, "surface_time_msec": run_state.simulation_time_msec() + 5000})
		canvas.call("render_game_snapshot", page_surface)
		await process_frame
		await process_frame
		_check_hit_overlap(_array(canvas.get("hit_regions")), "casino %s" % page, failures)
	for page in ["line", "numbers", "props", "odds"]:
		var street_page_surface := game.surface_state(run_state, street_environment, {"craps_bet_page": page})
		canvas.call("render_game_snapshot", street_page_surface)
		await process_frame
		await process_frame
		_check_hit_overlap(_array(canvas.get("hit_regions")), "street %s" % page, failures)
	root.remove_child(canvas)
	canvas.free()

	var rules := _dict(table.get("rules", {}))
	var rule_table := table.duplicate(true)
	rule_table["point"] = 5
	rule_table["working_bets"] = {"pass_line": 0, "dont_pass": 0, "pass_odds": 0, "dont_pass_odds": 0, "come": {}, "dont_come": {}, "come_odds": {}, "dont_come_odds": {}, "place": {}, "buy": {"5": 20}, "lay": {}, "hardways": {}, "big": {}, "working_on_come_out": false}
	if int(CrapsRulesScript.settle_roll(rule_table, {}, _roll(5), rules).get("bankroll_delta", 0)) != 29:
		failures.append("Buy-bet commission is not based on the wager amount.")
	var world_table := table.duplicate(true)
	world_table["point"] = 6
	world_table["working_bets"] = {}
	if int(CrapsRulesScript.settle_roll(world_table, {"world": 5}, _roll(7), rules).get("bankroll_delta", -1)) != 0:
		failures.append("World did not push on seven.")

	var perf_table := table.duplicate(true)
	perf_table["point"] = 6
	perf_table["working_bets"] = {}
	var perf_rng := run_state.create_rng("craps_rules_perf")
	var started_usec := Time.get_ticks_usec()
	for _index in range(10000):
		var roll := CrapsRulesScript.roll_dice(perf_rng, rules)
		CrapsRulesScript.settle_roll(perf_table, {}, roll, rules)
	var rules_msec := float(Time.get_ticks_usec() - started_usec) / 1000.0
	if rules_msec > 2000.0:
		failures.append("10,000 Craps rule resolutions exceeded 2 seconds: %.2f ms." % rules_msec)

	if failures.is_empty():
		print("CRAPS_FULL_TABLE_CONTRACT PASS rules_10000_msec=%.2f targets=%d" % [rules_msec, target_ids.size()])
		quit(0)
	else:
		_fail(failures)


func _craps_definition() -> Dictionary:
	var file := FileAccess.open("res://data/games/games.json", FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_ARRAY:
		return {}
	for value in parsed as Array:
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("id", "")) == "craps":
			return (value as Dictionary).duplicate(true)
	return {}


func _environment(street: bool) -> Dictionary:
	if street:
		return {"id": "street_craps_contract", "archetype_id": "back_alley", "game_ids": ["craps"], "scenario_game_modifiers": {"game_hook": "street_craps"}, "economic_profile": {"stake_floor": 2, "stake_ceiling": 20}}
	return {"id": "casino_craps_contract", "archetype_id": RunState.GRAND_CASINO_ARCHETYPE_ID, "kind": "boss", "game_ids": ["craps"], "economic_profile": {"stake_floor": 5, "stake_ceiling": 1000}}


func _rng_for_total(rules: Dictionary, wanted: int) -> RngStream:
	for seed in range(1, 1000):
		var probe := RngStream.new()
		probe.configure(seed)
		if int(CrapsRulesScript.roll_dice(probe, rules).get("total", 0)) == wanted:
			var result := RngStream.new()
			result.configure(seed)
			return result
	var fallback := RngStream.new()
	fallback.configure(1)
	return fallback


func _roll(total: int) -> Dictionary:
	var first := clampi(total - 1, 1, 6)
	return {"dice": [first, total - first], "total": total, "initial_total": total, "setting_bias_applied": false}


func _target_ids(value: Variant) -> Array:
	var result: Array = []
	for target_value in _array(value):
		if typeof(target_value) == TYPE_DICTIONARY:
			result.append(str((target_value as Dictionary).get("id", "")))
	return result


func _check_selectable_targets(game: GameModule, run_state: RunState, environment: Dictionary, surface: Dictionary, label: String, failures: Array[String]) -> void:
	var targets := _array(surface.get("bet_targets", []))
	for index in range(targets.size()):
		var target := _dict(targets[index])
		if not bool(target.get("enabled", false)):
			continue
		var target_id := str(target.get("id", ""))
		var command := game.surface_action_command("craps_bet", index, false, {"selected_chip": 5, "craps_bet_page": str(target.get("page", "line"))}, run_state, environment)
		if int(_dict(_dict(command.get("ui_state", {})).get("craps_pending_bets", {})).get(target_id, 0)) != 5:
			failures.append("%s target %s was visible and enabled but not selectable." % [label, target_id])


func _check_hit_overlap(regions: Array, label: String, failures: Array[String]) -> void:
	for first_index in range(regions.size()):
		var first := _dict(regions[first_index])
		var first_rect: Rect2 = first.get("rect", Rect2())
		for second_index in range(first_index + 1, regions.size()):
			var second := _dict(regions[second_index])
			var second_rect: Rect2 = second.get("rect", Rect2())
			if first_rect.has_area() and second_rect.has_area() and first_rect.intersection(second_rect).has_area():
				failures.append("%s overlaps %s with %s." % [label, str(first.get("action", "unknown")), str(second.get("action", "unknown"))])
				return


func _dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _array(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []


func _fail(failures: Array[String]) -> void:
	for failure in failures:
		push_error(failure)
	quit(1)
