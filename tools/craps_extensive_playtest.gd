extends SceneTree

const CrapsGameScript := preload("res://scripts/games/craps.gd")
const CrapsRulesScript := preload("res://scripts/games/craps/craps_rules.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const GameSurfaceCanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")

const REPORT_PATH := "res://review_artifacts/craps_rework/audit_report.json"
const PAGES := ["line", "numbers", "props", "odds"]

var failures: Array[String] = []
var checks := 0
var metrics := {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var definition := _craps_definition()
	_check(not definition.is_empty(), "The production Craps definition loads.")
	if definition.is_empty():
		_finish()
		return
	var game: GameModule = CrapsGameScript.new()
	game.setup(definition)
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("CRAPS-EXTENSIVE-PLAYTEST")
	run_state.bankroll = 100000
	run_state.grand_casino_chips = 100000

	_test_surface_and_controls(game, run_state, false)
	_test_surface_and_controls(game, run_state, true)
	_test_rules_matrix(definition)
	_test_shooter_and_currency(game, false)
	_test_shooter_and_currency(game, true)
	_test_performance(game, run_state)
	await _test_rendered_hit_regions(game, run_state)
	_finish()


func _test_surface_and_controls(game: GameModule, run_state: RunState, street: bool) -> void:
	var label := "street" if street else "casino"
	var environment := _environment(street)
	var table := game.generate_environment_state(run_state, environment, run_state.create_rng("craps_audit_%s" % label))
	environment["game_states"] = {"craps": table}
	run_state.current_environment = environment
	var base_surface := game.surface_state(run_state, environment, {})
	_check(str(base_surface.get("surface_template", "")) == "shared_table_game_v1", "%s uses the shared table environment." % label)
	_check(_array(base_surface.get("patrons", [])).size() == (6 if street else 5), "%s has its full live table cast." % label)
	_check(str(base_surface.get("currency", "chips")) == ("cash" if street else "chips"), "%s exposes the correct currency." % label)
	_check(not bool(base_surface.get("can_roll", true)) and bool(base_surface.get("can_pass_dice", false)), "%s requires a line bet before the player's come-out, but permits passing the dice." % label)

	var chips := _array(base_surface.get("chip_denominations", []))
	for chip_index in range(chips.size()):
		var chip_command := game.surface_action_command("craps_chip", chip_index, false, {}, run_state, environment)
		_check(int(_dict(chip_command.get("ui_state", {})).get("selected_chip", -1)) == int(chips[chip_index]), "%s denomination %s is selectable." % [label, str(chips[chip_index])])
	for page_index in range(PAGES.size()):
		var page_command := game.surface_action_command("craps_bet_page", page_index, false, {}, run_state, environment)
		_check(str(_dict(page_command.get("ui_state", {})).get("craps_bet_page", "")) == str(PAGES[page_index]), "%s %s page control works." % [label, str(PAGES[page_index])])

	var chip := int(chips[0])
	if chip < int(table.get("table_minimum", 1)):
		chip = int(table.get("table_minimum", 1))
	var ui := {"selected_chip": chip, "craps_bet_page": "line"}
	var pass_index := _target_index(base_surface, "pass_line")
	_check(pass_index >= 0, "%s Pass Line target exists." % label)
	if pass_index >= 0:
		var placed := game.surface_action_command("craps_bet", pass_index, false, ui, run_state, environment)
		ui = _dict(placed.get("ui_state", {}))
		_check(int(_dict(ui.get("craps_pending_bets", {})).get("pass_line", 0)) == chip, "%s Pass Line accepts a chip." % label)
		var stacked := game.surface_action_command("craps_bet", pass_index, false, ui, run_state, environment)
		ui = _dict(stacked.get("ui_state", {}))
		_check(int(_dict(ui.get("craps_pending_bets", {})).get("pass_line", 0)) == chip * 2, "%s Pass Line accepts a deliberate second chip." % label)
		var removed := game.surface_action_command("craps_remove", 0, false, ui, run_state, environment)
		ui = _dict(removed.get("ui_state", {}))
		_check(int(_dict(ui.get("craps_pending_bets", {})).get("pass_line", 0)) == chip, "%s REMOVE returns one selected chip." % label)
		var undone := game.surface_action_command("craps_undo", 0, false, ui, run_state, environment)
		ui = _dict(undone.get("ui_state", {}))
		_check(int(_dict(ui.get("craps_pending_bets", {})).get("pass_line", 0)) == chip * 2, "%s UNDO restores the prior layout." % label)
		var cleared := game.surface_action_command("craps_clear", 0, false, ui, run_state, environment)
		ui = _dict(cleared.get("ui_state", {}))
		_check(_dict(ui.get("craps_pending_bets", {})).is_empty(), "%s CLEAR removes pending wagers." % label)
		var restored := game.surface_action_command("craps_undo", 0, false, ui, run_state, environment)
		ui = _dict(restored.get("ui_state", {}))
		_check(int(_dict(ui.get("craps_pending_bets", {})).get("pass_line", 0)) == chip * 2, "%s UNDO restores a cleared layout." % label)
		var roll_command := game.surface_action_command("craps_roll", 0, false, ui, run_state, environment)
		_check(str(roll_command.get("action_id", "")) == "roll_craps", "%s THROW/CALL ROLL produces a resolvable roll command." % label)

	# Point-on coverage makes every normal and odds wager available and verifies
	# the exact target index the rendered surface sends back to the game module.
	table["point"] = 6
	table["working_bets"] = _rich_working_bets(10 if not street else 2)
	environment["game_states"] = {"craps": table}
	var enabled_count := 0
	for page in PAGES:
		var state := game.surface_state(run_state, environment, {"selected_chip": chip, "craps_bet_page": page})
		for target_index in range(_array(state.get("bet_targets", [])).size()):
			var target := _dict(_array(state.get("bet_targets", []))[target_index])
			if str(target.get("page", "")) != str(page) or not bool(target.get("enabled", false)):
				continue
			enabled_count += 1
			var command := game.surface_action_command("craps_bet", target_index, false, {"selected_chip": chip, "craps_bet_page": page}, run_state, environment)
			_check(int(_dict(_dict(command.get("ui_state", {})).get("craps_pending_bets", {})).get(str(target.get("id", "")), 0)) == chip, "%s target %s is selectable from the rendered index." % [label, str(target.get("id", ""))])
	_check(enabled_count >= 30, "%s exposes the full point-on wager set." % label)

	# Working wager selection is global-indexed across pages, including page two.
	var working_state := game.surface_state(run_state, environment, {"craps_working_page": 1})
	_check_presentation_clear(_array(working_state.get("bet_targets", [])), street, label)
	var rows := _array(working_state.get("working_bet_rows", []))
	_check(rows.size() > 5 and int(working_state.get("working_bet_page_count", 1)) > 1, "%s working wager rail paginates." % label)
	if rows.size() > 5:
		var select_command := game.surface_action_command("craps_working_select", 5, false, {"craps_working_page": 1}, run_state, environment)
		_check(str(_dict(select_command.get("ui_state", {})).get("craps_selected_working_id", "")) == str(_dict(rows[5]).get("id", "")), "%s second-page working wager is selectable." % label)
	var page_command := game.surface_action_command("craps_working_page", 1, false, {"craps_working_page": 0}, run_state, environment)
	_check(int(_dict(page_command.get("ui_state", {})).get("craps_working_page", 0)) == 1, "%s working wager next-page control works." % label)

	# A roll animation and a focused conversation must remove all stale gameplay
	# hit intent as well as reject direct commands without charging the player.
	var now := maxi(10000, run_state.simulation_time_msec())
	table["last_roll"] = {"dice": [3, 4], "total": 7, "resolved_at_msec": now, "animation_id": "audit-lock", "throw_trajectory": {}}
	environment["game_states"] = {"craps": table}
	var rolling := game.surface_state(run_state, environment, {"surface_time_msec": now + 10, "craps_bet_page": "numbers"})
	_check(bool(rolling.get("interaction_locked", false)) and not bool(rolling.get("can_roll", true)), "%s locks controls while dice are moving." % label)
	_check(_enabled_target_count(rolling) == 0, "%s has no enabled wager target while dice are moving." % label)
	var blocked_roll := game.surface_action_command("craps_chip", 0, false, {"surface_time_msec": now + 10}, run_state, environment)
	_check(not str(blocked_roll.get("message", "")).is_empty() and str(blocked_roll.get("action_id", "")).is_empty(), "%s rejects a direct control command during the roll." % label)
	table["last_roll"] = {}
	environment["game_states"] = {"craps": table}
	var talk_ui := {"focused_talk_speaker": {"role": "patron", "patron_index": 0}, "craps_bet_page": "numbers"}
	var talking := game.surface_state(run_state, environment, talk_ui)
	_check(bool(talking.get("interaction_locked", false)) and bool(talking.get("table_talk_active", false)), "%s recognizes focused table conversation." % label)
	_check(_enabled_target_count(talking) == 0 and not bool(talking.get("can_roll", true)), "%s dialogue focus disables every wager and roll control." % label)
	var blocked_talk := game.surface_action_command("craps_bet_page", 1, false, talk_ui, run_state, environment)
	_check(str(blocked_talk.get("action_id", "")).is_empty(), "%s direct table input is rejected during dialogue." % label)


func _test_rules_matrix(definition: Dictionary) -> void:
	var rules := _dict(_dict(definition.get("craps_config", {})).get("rules", {}))
	_check(_delta(rules, 0, _empty_working(), {"pass_line": 5}, 7) == 5, "Pass Line wins on a come-out seven.")
	_check(_delta(rules, 0, _empty_working(), {"pass_line": 5}, 2) == -5, "Pass Line loses on come-out craps.")
	_check(_delta(rules, 0, _empty_working(), {"dont_pass": 5}, 12) == 0, "Don't Pass bars twelve as a push.")
	_check(_delta(rules, 0, _empty_working(), {"dont_pass": 5}, 3) == 5, "Don't Pass wins on come-out three.")

	var pass_point := _empty_working()
	pass_point["pass_line"] = 5
	pass_point["pass_odds"] = 10
	_check(_delta(rules, 4, pass_point, {}, 4) == 40, "Pass Line plus 2:1 odds pays and returns both stakes on four.")
	var dont_point := _empty_working()
	dont_point["dont_pass"] = 5
	dont_point["dont_pass_odds"] = 10
	_check(_delta(rules, 4, dont_point, {}, 7) == 25, "Don't Pass plus lay odds pays and returns both stakes on seven.")

	var moving := _empty_working()
	var move_result := CrapsRulesScript.settle_roll({"point": 6, "working_bets": moving}, {"come": 5, "dont_come": 5}, _roll(5), rules)
	_check(int(_dict(_dict(move_result.get("working_bets", {})).get("come", {})).get("5", 0)) == 5, "Come wager travels to its rolled number.")
	_check(int(_dict(_dict(move_result.get("working_bets", {})).get("dont_come", {})).get("5", 0)) == 5, "Don't Come wager travels behind its rolled number.")
	var come_hit := _empty_working()
	come_hit["come"] = {"5": 5}
	come_hit["come_odds"] = {"5": 10}
	_check(_delta(rules, 6, come_hit, {}, 5) == 35, "Come and its odds pay together when the number repeats.")
	var dont_hit := _empty_working()
	dont_hit["dont_come"] = {"9": 5}
	dont_hit["dont_come_odds"] = {"9": 6}
	_check(_delta(rules, 6, dont_hit, {}, 7) == 20, "Don't Come and its lay odds pay together on seven.")

	var place := _empty_working()
	place["place"] = {"6": 6}
	_check(_delta(rules, 6, place, {}, 6) == 7 and int(_dict(place.get("place", {})).get("6", 0)) == 6, "Place six pays 7:6 and remains working.")
	var buy := _empty_working()
	buy["buy"] = {"4": 20}
	_check(_delta(rules, 6, buy, {}, 4) == 39, "Buy four pays true odds less the wager-based vig.")
	var lay := _empty_working()
	lay["lay"] = {"4": 20}
	_check(_delta(rules, 6, lay, {}, 7) == 9 and int(_dict(lay.get("lay", {})).get("4", 0)) == 20, "Lay four wins on seven and remains working.")
	var big := _empty_working()
	big["big"] = {"6": 5}
	_check(_delta(rules, 6, big, {}, 6) == 5, "Big Six pays even money and remains working.")

	var hard_win := _empty_working()
	hard_win["hardways"] = {"6": 1}
	_check(_delta(rules, 6, hard_win, {}, 6, [3, 3]) == 9 and int(_dict(hard_win.get("hardways", {})).get("6", 0)) == 1, "Hard six pays 9:1 on a pair and remains working.")
	var hard_easy := _empty_working()
	hard_easy["hardways"] = {"6": 1}
	_check(_delta(rules, 6, hard_easy, {}, 6, [2, 4]) == 0, "Hard six loses on an easy six.")

	for total in [2, 3, 4, 9, 10, 11, 12]:
		_check(_delta(rules, 6, _empty_working(), {"field": 1}, total) > 0, "Field pays on %d." % total)
	for total in [5, 6, 7, 8]:
		_check(_delta(rules, 6, _empty_working(), {"field": 1}, total) == -1, "Field loses on %d." % total)
	var props := {"any_seven": 7, "any_craps": 3, "snake_eyes": 2, "ace_deuce": 3, "yo": 11, "boxcars": 12}
	for bet_id in props.keys():
		_check(_delta(rules, 6, _empty_working(), {bet_id: 1}, int(props[bet_id])) > 0, "%s proposition wins on its posted total." % str(bet_id))
	_check(_delta(rules, 6, _empty_working(), {"horn": 5}, 12) == 57, "Horn High 12 allocates whole units and pays the high side correctly.")
	_check(_delta(rules, 6, _empty_working(), {"ce": 2}, 11) == 14, "C & E pays the eleven side correctly.")
	_check(_delta(rules, 6, _empty_working(), {"world": 5}, 7) == 0, "World pushes on seven.")

	var off := _empty_working()
	off["place"] = {"6": 6}
	off["hardways"] = {"6": 1}
	_check(_delta(rules, 0, off, {}, 6, [3, 3]) == 0, "Place and hardway bets are off by default on the come-out.")
	off["working_on_come_out"] = true
	_check(_delta(rules, 0, off, {}, 6, [3, 3]) == 16, "WORKING toggle activates place and hardway bets on the come-out.")


func _test_shooter_and_currency(game: GameModule, street: bool) -> void:
	var label := "street" if street else "casino"
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("CRAPS-SHOOTER-%s" % label)
	run_state.bankroll = 1000
	run_state.grand_casino_chips = 1000
	var environment := _environment(street)
	var table := game.generate_environment_state(run_state, environment, run_state.create_rng("craps_shooter_table_%s" % label))
	table["point"] = 6
	table["shooter_index"] = 0
	table["working_bets"] = _empty_working()
	table["working_bets"]["pass_line"] = 5 if not street else 2
	environment["game_states"] = {"craps": table}
	run_state.current_environment = environment
	var before_cash := run_state.bankroll
	var before_chips := run_state.grand_casino_chips
	var result := game.resolve_with_context("roll_craps", 0, run_state, environment, _rng_for_total(_dict(table.get("rules", {})), 7), {"craps_pending_bets": {"any_seven": 5}})
	_check(bool(result.get("ok", false)) and str(_dict(result.get("craps_shooter", {})).get("id", "player")) != "player", "%s seven-out rotates the shooter exactly once." % label)
	_check(str(_dict(result.get("craps_table_talk_request", {})).get("reaction", "")) == "seven_out_player", "%s seven-out produces player-directed table chatter." % label)
	if street:
		_check(run_state.bankroll != before_cash and run_state.grand_casino_chips == before_chips, "Street Craps settles cash without touching casino chips.")
	else:
		_check(run_state.grand_casino_chips != before_chips and run_state.bankroll == before_cash, "Casino Craps settles chips without touching cash.")


func _test_performance(game: GameModule, run_state: RunState) -> void:
	var environment := _environment(false)
	var table := game.generate_environment_state(run_state, environment, run_state.create_rng("craps_perf_table"))
	table["point"] = 6
	table["working_bets"] = _rich_working_bets(10)
	environment["game_states"] = {"craps": table}
	run_state.current_environment = environment
	var start_usec := Time.get_ticks_usec()
	for index in range(1000):
		game.surface_state(run_state, environment, {"craps_bet_page": PAGES[index % PAGES.size()], "selected_chip": 5, "surface_time_msec": index * 2000})
	var surface_msec := float(Time.get_ticks_usec() - start_usec) / 1000.0
	metrics["surface_state_1000_msec"] = snappedf(surface_msec, 0.01)
	_check(surface_msec < 2500.0, "1,000 full Craps surface projections complete in under 2.5 seconds (%.2f ms)." % surface_msec)
	var rules := _dict(table.get("rules", {}))
	var perf_rng := run_state.create_rng("craps_rules_perf_extensive")
	start_usec = Time.get_ticks_usec()
	for _index in range(100000):
		CrapsRulesScript.settle_roll({"point": 6, "working_bets": _empty_working()}, {"field": 1}, CrapsRulesScript.roll_dice(perf_rng, rules), rules)
	var rules_msec := float(Time.get_ticks_usec() - start_usec) / 1000.0
	metrics["rule_settlements_100000_msec"] = snappedf(rules_msec, 0.01)
	_check(rules_msec < 10000.0, "100,000 wager settlements complete in under ten seconds (%.2f ms)." % rules_msec)


func _test_rendered_hit_regions(game: GameModule, run_state: RunState) -> void:
	var canvas: Control = GameSurfaceCanvasScript.new()
	canvas.size = Vector2(1280, 720)
	root.add_child(canvas)
	canvas.call("set_game_module", game)
	for street in [false, true]:
		var label := "street" if street else "casino"
		var environment := _environment(street)
		var table := game.generate_environment_state(run_state, environment, run_state.create_rng("craps_hit_%s" % label))
		table["point"] = 6
		table["working_bets"] = _rich_working_bets(10 if not street else 2)
		environment["game_states"] = {"craps": table}
		run_state.current_environment = environment
		for page in PAGES:
			var state := game.surface_state(run_state, environment, {"craps_bet_page": page, "selected_chip": 5 if not street else 2})
			canvas.call("render_game_snapshot", state)
			await process_frame
			await process_frame
			_check_no_hit_overlap(_array(canvas.get("hit_regions")), "%s %s" % [label, str(page)])
		var now := maxi(10000, run_state.simulation_time_msec())
		table["last_roll"] = {"dice": [3, 4], "total": 7, "resolved_at_msec": now, "animation_id": "hit-lock", "throw_trajectory": {}}
		environment["game_states"] = {"craps": table}
		canvas.call("render_game_snapshot", game.surface_state(run_state, environment, {"surface_time_msec": now + 10}))
		await process_frame
		await process_frame
		_check(_craps_hit_count(_array(canvas.get("hit_regions"))) == 0, "%s roll animation exposes no stale Craps hit regions." % label)
		table["last_roll"] = {}
		environment["game_states"] = {"craps": table}
		canvas.call("render_game_snapshot", game.surface_state(run_state, environment, {"focused_talk_speaker": {"role": "patron", "patron_index": 0}}))
		await process_frame
		await process_frame
		_check(_craps_hit_count(_array(canvas.get("hit_regions"))) == 0, "%s focused dialogue exposes no stale Craps hit regions." % label)
	root.remove_child(canvas)
	canvas.free()


func _delta(rules: Dictionary, point: int, working: Dictionary, pending: Dictionary, total: int, dice: Array = []) -> int:
	var table := {"point": point, "working_bets": working, "roll_count": 0, "hot_shooter_streak": 0, "table_energy": 0}
	var actual_dice := dice if dice.size() == 2 else _dice_for_total(total)
	return int(CrapsRulesScript.settle_roll(table, pending, {"dice": actual_dice, "total": total}, rules).get("bankroll_delta", 0))


func _dice_for_total(total: int) -> Array:
	var first := clampi(total - 1, 1, 6)
	return [first, total - first]


func _roll(total: int) -> Dictionary:
	return {"dice": _dice_for_total(total), "total": total, "initial_total": total, "setting_bias_applied": false}


func _empty_working() -> Dictionary:
	return {"pass_line": 0, "dont_pass": 0, "pass_odds": 0, "dont_pass_odds": 0, "come": {}, "dont_come": {}, "come_odds": {}, "dont_come_odds": {}, "place": {}, "buy": {}, "lay": {}, "hardways": {}, "big": {}, "working_on_come_out": false}


func _rich_working_bets(stake: int) -> Dictionary:
	return {"pass_line": stake, "dont_pass": stake, "pass_odds": 0, "dont_pass_odds": 0, "come": {"5": stake}, "dont_come": {"9": stake}, "come_odds": {"5": stake}, "dont_come_odds": {"9": stake}, "place": {"4": stake, "6": stake}, "buy": {"5": stake}, "lay": {"10": stake}, "hardways": {"4": stake, "8": stake}, "big": {"6": stake}, "working_on_come_out": false}


func _target_index(surface: Dictionary, id: String) -> int:
	var targets := _array(surface.get("bet_targets", []))
	for index in range(targets.size()):
		if str(_dict(targets[index]).get("id", "")) == id:
			return index
	return -1


func _enabled_target_count(surface: Dictionary) -> int:
	var count := 0
	for value in _array(surface.get("bet_targets", [])):
		if bool(_dict(value).get("enabled", false)):
			count += 1
	return count


func _check_no_hit_overlap(regions: Array, label: String) -> void:
	for first_index in range(regions.size()):
		var first := _dict(regions[first_index])
		var first_rect: Rect2 = first.get("rect", Rect2())
		for second_index in range(first_index + 1, regions.size()):
			var second := _dict(regions[second_index])
			var second_rect: Rect2 = second.get("rect", Rect2())
			if first_rect.has_area() and second_rect.has_area() and first_rect.intersection(second_rect).has_area():
				_check(false, "%s has overlapping hit regions: %s and %s." % [label, str(first.get("action", "unknown")), str(second.get("action", "unknown"))])
				return
	_check(true, "%s rendered hit regions do not overlap." % label)


func _check_presentation_clear(targets: Array, street: bool, label: String) -> void:
	var exclusions := [Rect2(621, 135, 28, 103)] if street else [Rect2(668, 152, 91, 55), Rect2(708, 94, 36, 36)]
	for target_value in targets:
		var target := _dict(target_value)
		var target_rect: Rect2 = target.get("rect", Rect2())
		for exclusion in exclusions:
			if target_rect.intersection(exclusion).has_area():
				_check(false, "%s presentation objects overlap wager %s." % [label, str(target.get("id", "unknown"))])
				return
	_check(true, "%s resting dice and point marker remain outside every wager target." % label)


func _craps_hit_count(regions: Array) -> int:
	var count := 0
	for value in regions:
		if str(_dict(value).get("action", "")).begins_with("craps_"):
			count += 1
	return count


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
		return {"id": "craps_audit_street", "archetype_id": "back_alley", "game_ids": ["craps"], "economic_profile": {"stake_floor": 2, "stake_ceiling": 20}, "scenario_game_modifiers": {"game_hook": "street_craps"}}
	return {"id": "craps_audit_casino", "archetype_id": RunState.GRAND_CASINO_ARCHETYPE_ID, "kind": "boss", "game_ids": ["craps"], "economic_profile": {"stake_floor": 5, "stake_ceiling": 1000}}


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)


func _array(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []


func _dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _finish() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_PATH.get_base_dir()))
	var report := {
		"suite": "craps_extensive_playtest",
		"passed": failures.is_empty(),
		"checks": checks,
		"failures": failures,
		"metrics": metrics,
		"coverage": ["casino and Chalk Alley surfaces", "all four wager pages", "all enabled wager targets", "chip denominations", "pending wager correction", "working wager pagination", "roll and dialogue locks", "line, Come, odds, number, hardway, Field, proposition rules", "shooter rotation and chatter", "cash/chip isolation", "rendered hit-region overlap", "performance"],
	}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	if failures.is_empty():
		print("CRAPS_EXTENSIVE_PLAYTEST PASS checks=%d surface_1000_msec=%.2f rules_100000_msec=%.2f" % [checks, float(metrics.get("surface_state_1000_msec", 0.0)), float(metrics.get("rule_settlements_100000_msec", 0.0))])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
