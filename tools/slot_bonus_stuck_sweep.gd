extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const SlotGameScript := preload("res://scripts/games/slot.gd")
const GeneratorScript := preload("res://scripts/games/slots/slot_machine_generator.gd")
const StateScript := preload("res://scripts/games/slots/slot_machine_state.gd")
const BuffaloScript := preload("res://scripts/games/slots/slot_family_buffalo.gd")
const PinballScript := preload("res://scripts/games/slots/slot_family_pinball.gd")
const PinballFeatureScript := preload("res://scripts/games/slots/pinball/pinball_feature.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")

const WATCHDOG_GRACE_MSEC := 2200
const GENERAL_GAME_IDS := ["slot", "pull_tabs", "blackjack", "baccarat", "roulette", "video_poker", "bar_dice"]
const ROULETTE_PAST_POST_SURFACE_MSEC := 5700
const PULL_TAB_ANIMATION_SETTLED_MSEC := 2500
const BAR_DICE_TUMBLE_SETTLED_MSEC := 1400


func _init() -> void:
	var seed_count := _seed_count()
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	var game_modules := _build_game_modules(library)
	var definition: Dictionary = library.game("slot")
	var game: GameModule = game_modules.get("slot", null) as GameModule
	if game == null:
		game = SlotGameScript.new()
		game.setup(definition, library)
	var scenarios: Array = _scenario_combos(definition)
	var failures: Array = []
	var counts: Dictionary = {}
	for seed_index in range(seed_count):
		var scenario: Dictionary = _dict(scenarios[seed_index % scenarios.size()])
		var key := _scenario_key(scenario)
		counts[key] = int(counts.get(key, 0)) + 1
		var result: Dictionary = _run_scenario(game, definition, scenario, seed_index)
		if not bool(result.get("ok", false)):
			failures.append(str(result.get("failure", "unknown failure")))
		for wait_result_value in _run_wait_state_scenarios(library, game_modules, seed_index):
			var wait_result: Dictionary = _dict(wait_result_value)
			var wait_key := str(wait_result.get("scenario", "unknown_wait_state"))
			counts[wait_key] = int(counts.get(wait_key, 0)) + 1
			if not bool(wait_result.get("ok", false)):
				failures.append(str(wait_result.get("failure", "unknown wait-state failure")))
	if failures.is_empty():
		print("GENERAL_STUCK_STATE_SWEEP status=PASS seeds=%d slot_scenarios=%d wait_scenarios=%d stuck=0 counts=%s" % [seed_count, scenarios.size(), _wait_state_scenario_names().size(), JSON.stringify(counts)])
		quit(0)
		return
	var shown: Array = failures.slice(0, mini(20, failures.size()))
	print("GENERAL_STUCK_STATE_SWEEP status=FAIL seeds=%d failures=%d details=%s" % [seed_count, failures.size(), JSON.stringify(shown)])
	quit(1)


func _seed_count() -> int:
	var seeds := 200
	var env_seed_count := OS.get_environment("BTH_STUCK_SWEEP_SEEDS").strip_edges()
	if env_seed_count.is_valid_int():
		seeds = maxi(1, int(env_seed_count))
	for raw_arg in OS.get_cmdline_user_args():
		var arg := str(raw_arg)
		if arg.begins_with("--seeds="):
			seeds = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.is_valid_int():
			seeds = maxi(1, int(arg))
	return seeds


func _scenario_combos(definition: Dictionary) -> Array:
	var formats: Array = _ids(definition.get("slot_formats", []))
	var bonus_ids: Array = _ids(definition.get("slot_bonus_variants", []))
	var scenarios: Array = []
	for bonus_value in bonus_ids:
		var bonus_id := str(bonus_value)
		for format_value in formats:
			var format_id := str(format_value)
			scenarios.append({"family": "pinball", "format": format_id, "bonus": bonus_id, "mode": "pinball"})
			for buffalo_mode in ["free_games", "hold_and_spin", "monster_feature"]:
				scenarios.append({"family": "buffalo", "format": format_id, "bonus": bonus_id, "mode": str(buffalo_mode)})
	return scenarios


func _build_game_modules(library: ContentLibrary) -> Dictionary:
	var modules: Dictionary = {}
	for game_value in library.games:
		if typeof(game_value) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = game_value
		var game_id := str(definition.get("id", "")).strip_edges()
		var module_path := str(definition.get("module_path", "")).strip_edges()
		if game_id.is_empty() or module_path.is_empty() or module_path.ends_with("_ui.gd") or module_path.begins_with("res://data/runtime/"):
			continue
		var module_script: Script = load(module_path)
		if module_script == null:
			continue
		var module_instance: Object = module_script.new()
		if not module_instance is GameModule:
			continue
		var game: GameModule = module_instance
		game.setup(definition, library)
		modules[game_id] = game
	return modules


func _wait_state_scenario_names() -> Array:
	return [
		"blackjack_count_settlement_preview",
		"baccarat_edge_sort_memory",
		"roulette_past_post_window",
		"video_poker_holdout_and_double",
		"bar_dice_controlled_roll",
		"pull_tabs_reveal_and_file",
		"triggered_event_queue",
		"travel_lock_countdown",
	]


func _run_wait_state_scenarios(library: ContentLibrary, game_modules: Dictionary, seed_index: int) -> Array:
	return [
		_run_blackjack_count_wait(game_modules, seed_index),
		_run_baccarat_edge_sort_wait(game_modules, seed_index),
		_run_roulette_past_post_wait(game_modules, seed_index),
		_run_video_poker_waits(game_modules, seed_index),
		_run_bar_dice_controlled_roll_wait(game_modules, seed_index),
		_run_pull_tabs_wait(game_modules, seed_index),
		_run_triggered_event_wait(library, seed_index),
		_run_travel_lock_wait(seed_index),
	]


func _run_blackjack_count_wait(game_modules: Dictionary, seed_index: int) -> Dictionary:
	var label := "SB6-WAIT-%03d-blackjack-count" % seed_index
	var context := _fixture_context(game_modules, "blackjack", label)
	if not bool(context.get("ok", false)):
		return _scenario_fail("blackjack_count_settlement_preview", label, str(context.get("failure", "fixture failed")))
	var dealt := _surface_action(context, "blackjack_deal", 0, false, label)
	if not bool(dealt.get("ok", false)):
		return _scenario_fail("blackjack_count_settlement_preview", label, str(dealt.get("failure", "deal failed")))
	var count := _surface_action(context, "blackjack_count", 0, false, label)
	if not bool(count.get("ok", false)):
		return _scenario_fail("blackjack_count_settlement_preview", label, str(count.get("failure", "count arm failed")))
	_restore_context(context)
	var preview := _surface_action(context, "blackjack_deal", 0, false, label)
	if not bool(preview.get("ok", false)):
		return _scenario_fail("blackjack_count_settlement_preview", label, str(preview.get("failure", "settlement preview failed")))
	var settled := _surface_action(context, "blackjack_deal", 0, false, label)
	if not bool(settled.get("ok", false)):
		return _scenario_fail("blackjack_count_settlement_preview", label, str(settled.get("failure", "settlement resolve failed")))
	var ui_state: Dictionary = _dict(context.get("ui_state", {}))
	if bool(ui_state.get("settlement_pending", false)):
		return _scenario_fail("blackjack_count_settlement_preview", label, "settlement_pending survived normal settle path")
	return _scenario_ok("blackjack_count_settlement_preview")


func _run_baccarat_edge_sort_wait(game_modules: Dictionary, seed_index: int) -> Dictionary:
	var label := "SB6-WAIT-%03d-baccarat-edge" % seed_index
	var context := _fixture_context(game_modules, "baccarat", label)
	if not bool(context.get("ok", false)):
		return _scenario_fail("baccarat_edge_sort_memory", label, str(context.get("failure", "fixture failed")))
	var started := _surface_action(context, "baccarat_edge_sort", 0, false, label)
	if not bool(started.get("ok", false)):
		return _scenario_fail("baccarat_edge_sort_memory", label, str(started.get("failure", "edge-sort start failed")))
	for hand_index in range(4):
		context["ui_state"] = {"baccarat_sit_out": true, "surface_time_msec": 1000 + hand_index * 7000}
		var hand := _resolve_context_action(context, "deal_baccarat", label, false)
		if not bool(hand.get("ok", false)):
			return _scenario_fail("baccarat_edge_sort_memory", label, str(hand.get("failure", "observation hand failed")))
	var table: Dictionary = _game_state_from_context(context, "baccarat")
	var challenge: Dictionary = _dict(table.get("edge_sort_challenge", {}))
	if challenge.is_empty() or not bool(challenge.get("ready", false)):
		return _scenario_fail("baccarat_edge_sort_memory", label, "edge-sort challenge never became ready")
	var last_result: Dictionary = _dict(table.get("last_result", {}))
	context["ui_state"] = {
		"edge_sort_challenge": challenge,
		"edge_sort_answer_mode": "perfect",
		"surface_time_msec": int(last_result.get("resolved_at_msec", 0)) + 7000,
	}
	_restore_context(context)
	var committed := _surface_action(context, "baccarat_edge_sort", 0, false, label)
	if not bool(committed.get("ok", false)):
		return _scenario_fail("baccarat_edge_sort_memory", label, str(committed.get("failure", "edge-sort commit failed")))
	var after_table: Dictionary = _game_state_from_context(context, "baccarat")
	if not _dict(after_table.get("edge_sort_challenge", {})).is_empty():
		return _scenario_fail("baccarat_edge_sort_memory", label, "edge-sort challenge remained active after commit")
	return _scenario_ok("baccarat_edge_sort_memory")


func _run_roulette_past_post_wait(game_modules: Dictionary, seed_index: int) -> Dictionary:
	var label := "SB6-WAIT-%03d-roulette-past-post" % seed_index
	var context := _fixture_context(game_modules, "roulette", label)
	if not bool(context.get("ok", false)):
		return _scenario_fail("roulette_past_post_window", label, str(context.get("failure", "fixture failed")))
	context["ui_state"] = {"roulette_bets": [_roulette_bet(10)], "surface_time_msec": 1000}
	var spin := _resolve_context_action(context, "spin_roulette", label, false)
	if not bool(spin.get("ok", false)):
		return _scenario_fail("roulette_past_post_window", label, str(spin.get("failure", "spin failed")))
	var table: Dictionary = _game_state_from_context(context, "roulette")
	var last_result: Dictionary = _dict(table.get("last_result", {}))
	if last_result.is_empty():
		return _scenario_fail("roulette_past_post_window", label, "roulette spin left no result")
	var surface_time := int(last_result.get("resolved_at_msec", 0)) + ROULETTE_PAST_POST_SURFACE_MSEC
	context["ui_state"] = {"surface_time_msec": surface_time, "selected_chip": 1}
	var armed := _surface_action(context, "roulette_past_post", 0, false, label)
	if not bool(armed.get("ok", false)):
		return _scenario_fail("roulette_past_post_window", label, str(armed.get("failure", "past-post arm failed")))
	_restore_context(context)
	context["ui_state"] = _dict(context.get("ui_state", {}))
	context["ui_state"]["surface_time_msec"] = surface_time + 80
	var resolved := _surface_action(context, "roulette_past_post", 0, false, label)
	if not bool(resolved.get("ok", false)):
		return _scenario_fail("roulette_past_post_window", label, str(resolved.get("failure", "past-post resolve failed")))
	var after_table: Dictionary = _game_state_from_context(context, "roulette")
	var after_result: Dictionary = _dict(after_table.get("last_result", {}))
	if not bool(after_result.get("past_post_resolved", false)):
		return _scenario_fail("roulette_past_post_window", label, "past-post resolved action did not mark the result")
	return _scenario_ok("roulette_past_post_window")


func _run_video_poker_waits(game_modules: Dictionary, seed_index: int) -> Dictionary:
	var label := "SB6-WAIT-%03d-video-poker" % seed_index
	var context := _fixture_context(game_modules, "video_poker", label)
	if not bool(context.get("ok", false)):
		return _scenario_fail("video_poker_holdout_and_double", label, str(context.get("failure", "fixture failed")))
	for action_name in ["video_poker_deal", "video_poker_mark", "video_poker_draw"]:
		var command := _surface_action(context, str(action_name), 0, action_name == "video_poker_draw", label)
		if not bool(command.get("ok", false)):
			return _scenario_fail("video_poker_holdout_and_double", label, str(command.get("failure", "%s failed" % action_name)))
		if action_name == "video_poker_mark":
			_restore_context(context)
	var state := _game_state_from_context(context, "video_poker")
	state["last_result"] = {
		"summary": "Fixture double-up win.",
		"win_credits": 10,
		"double_credits": 10,
		"double_chain": 0,
		"resolved_at_msec": 1200,
		"flip_id": "sb6_double_fixture",
	}
	_write_game_state_to_context(context, "video_poker", state)
	context["ui_state"] = {"hand_active": false, "collected": false}
	var double_started := _surface_action(context, "video_poker_double", 0, false, label)
	if not bool(double_started.get("ok", false)):
		return _scenario_fail("video_poker_holdout_and_double", label, str(double_started.get("failure", "double start failed")))
	_restore_context(context)
	var double_selected := _surface_action(context, "video_poker_double_pick", 1, false, label)
	if not bool(double_selected.get("ok", false)):
		return _scenario_fail("video_poker_holdout_and_double", label, str(double_selected.get("failure", "double pick failed")))
	var double_resolved := _surface_action(context, "video_poker_double_pick", 1, false, label)
	if not bool(double_resolved.get("ok", false)):
		return _scenario_fail("video_poker_holdout_and_double", label, str(double_resolved.get("failure", "double resolve failed")))
	var after_state := _game_state_from_context(context, "video_poker")
	if str(_dict(after_state.get("last_result", {})).get("double_outcome", "")).is_empty():
		return _scenario_fail("video_poker_holdout_and_double", label, "double-up prompt did not resolve through normal pick path")
	return _scenario_ok("video_poker_holdout_and_double")


func _run_bar_dice_controlled_roll_wait(game_modules: Dictionary, seed_index: int) -> Dictionary:
	var label := "SB6-WAIT-%03d-bar-dice" % seed_index
	var context := _fixture_context(game_modules, "bar_dice", label)
	if not bool(context.get("ok", false)):
		return _scenario_fail("bar_dice_controlled_roll", label, str(context.get("failure", "fixture failed")))
	context["stake"] = 20
	var rolled := _surface_action(context, "bar_dice_roll", 0, false, label)
	if not bool(rolled.get("ok", false)):
		return _scenario_fail("bar_dice_controlled_roll", label, str(rolled.get("failure", "opening roll failed")))
	var loaded := _surface_action(context, "bar_dice_load", 0, false, label)
	if not bool(loaded.get("ok", false)):
		return _scenario_fail("bar_dice_controlled_roll", label, str(loaded.get("failure", "controlled roll arm failed")))
	_restore_context(context)
	var ui_state: Dictionary = _dict(context.get("ui_state", {}))
	ui_state["surface_time_msec"] = int(ui_state.get("surface_time_msec", 0)) + BAR_DICE_TUMBLE_SETTLED_MSEC
	ui_state["controlled_roll_input_msec"] = int(ui_state.get("surface_time_msec", 0))
	context["ui_state"] = ui_state
	var released := _surface_action(context, "bar_dice_release", 0, false, label)
	if not bool(released.get("ok", false)):
		return _scenario_fail("bar_dice_controlled_roll", label, str(released.get("failure", "controlled roll release failed")))
	var after_state := _game_state_from_context(context, "bar_dice")
	if _dict(after_state.get("last_result", {})).is_empty():
		return _scenario_fail("bar_dice_controlled_roll", label, "controlled roll did not settle a bar dice result")
	return _scenario_ok("bar_dice_controlled_roll")


func _run_pull_tabs_wait(game_modules: Dictionary, seed_index: int) -> Dictionary:
	var label := "SB6-WAIT-%03d-pull-tabs" % seed_index
	var context := _fixture_context(game_modules, "pull_tabs", label)
	if not bool(context.get("ok", false)):
		return _scenario_fail("pull_tabs_reveal_and_file", label, str(context.get("failure", "fixture failed")))
	var bought := _surface_action(context, "pull_tab_buy", 0, false, label)
	if not bool(bought.get("ok", false)):
		return _scenario_fail("pull_tabs_reveal_and_file", label, str(bought.get("failure", "ticket buy failed")))
	context["ui_state"] = {"surface_time_msec": PULL_TAB_ANIMATION_SETTLED_MSEC}
	var collected := _surface_action(context, "pull_tab_collect_tray", 0, false, label)
	if not bool(collected.get("ok", false)):
		return _scenario_fail("pull_tabs_reveal_and_file", label, str(collected.get("failure", "tray collect failed")))
	var revealed := _surface_action(context, "pull_tab_reveal_next", 0, false, label)
	if not bool(revealed.get("ok", false)):
		return _scenario_fail("pull_tabs_reveal_and_file", label, str(revealed.get("failure", "ticket reveal failed")))
	_restore_context(context)
	var filed := _surface_action(context, "pull_tab_file_ticket", 0, false, label)
	if not bool(filed.get("ok", false)):
		return _scenario_fail("pull_tabs_reveal_and_file", label, str(filed.get("failure", "ticket file failed")))
	var machine := _game_state_from_context(context, "pull_tabs")
	if _array(machine.get("ticket_stack", [])).size() > 0 and _array(machine.get("winner_pile", [])).is_empty() and _array(machine.get("loser_pile", [])).is_empty():
		return _scenario_fail("pull_tabs_reveal_and_file", label, "file action left all tickets in the active stack")
	return _scenario_ok("pull_tabs_reveal_and_file")


func _run_triggered_event_wait(library: ContentLibrary, seed_index: int) -> Dictionary:
	var scenario := "triggered_event_queue"
	var label := "SB6-WAIT-%03d-triggered-event" % seed_index
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(label)
	run_state.bankroll = 5000
	run_state.current_environment = {
		"id": "sb6_event_room",
		"archetype_id": "bar",
		"kind": "bar",
		"display_name": "SB6 Event Room",
		"game_ids": [],
		"game_states": {},
		"event_ids": ["family_loan"],
	}
	if not run_state.enqueue_triggered_event("family_loan", "sb6_sweep", {"source": "stuck_sweep"}):
		return _scenario_fail(scenario, label, "triggered event did not enqueue")
	var restored: RunState = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	var pending := restored.next_pending_triggered_event()
	if pending.is_empty():
		return _scenario_fail(scenario, label, "pending triggered event was lost on save/load")
	var active := restored.begin_triggered_event_resolution(pending)
	var event_id := str(active.get("event_id", ""))
	var event_def := library.event(event_id)
	if not event_def.is_empty():
		var event_module: EventModule = EventModuleScript.new()
		event_module.setup(event_def, library)
		var choices := event_module.choices(restored, restored.current_environment)
		if not choices.is_empty() and typeof(choices[0]) == TYPE_DICTIONARY:
			var choice: Dictionary = choices[0]
			event_module.resolve(restored, restored.current_environment, str(choice.get("id", "")))
	restored.complete_triggered_event_resolution(event_id)
	if restored.triggered_event_resolution_active() or not restored.next_pending_triggered_event().is_empty():
		return _scenario_fail(scenario, label, "triggered event queue remained active after normal completion")
	return _scenario_ok(scenario)


func _run_travel_lock_wait(seed_index: int) -> Dictionary:
	var scenario := "travel_lock_countdown"
	var label := "SB6-WAIT-%03d-travel-lock" % seed_index
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(label)
	run_state.current_environment = {
		"id": "sb6_travel_lock_room",
		"archetype_id": "bar",
		"kind": "bar",
		"display_name": "SB6 Travel Lock Room",
		"game_ids": [],
		"game_states": {},
		"travel_lock_remaining": 2,
	}
	var restored: RunState = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	if restored.current_travel_lock_remaining() != 2:
		return _scenario_fail(scenario, label, "travel lock did not survive save/load")
	restored.advance_environment_turns(2)
	if restored.current_travel_lock_remaining() > 0:
		return _scenario_fail(scenario, label, "travel lock did not count down through environment turns")
	return _scenario_ok(scenario)


func _run_scenario(game: GameModule, definition: Dictionary, scenario: Dictionary, seed_index: int) -> Dictionary:
	var seed_text := "R8-SLOT-BONUS-SWEEP-%03d-%s" % [seed_index, _scenario_key(scenario)]
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed_text)
	run_state.bankroll = 100000
	var environment := {
		"id": "slot_bonus_sweep_room",
		"archetype_id": "bar",
		"kind": "casino",
		"display_name": "Slot Bonus Sweep Room",
		"game_ids": ["slot"],
		"game_states": {},
		"economic_profile": {"stake_floor": 2, "stake_ceiling": 60, "cashout_tone": "test"},
		"security_profile": {"strictness": "loose"},
		"event_ids": [],
	}
	var machine: Dictionary = _machine(definition, run_state, scenario)
	var family := str(scenario.get("family", ""))
	var mode := str(scenario.get("mode", ""))
	var edge := seed_index % 8
	if family == "pinball":
		if edge == 0:
			return _run_pinball_watchdog_save_load(game, definition, run_state, environment, machine, seed_text)
		return _run_pinball_headless(game, definition, run_state, environment, machine, edge == 1, seed_text)
	if mode == "hold_and_spin" and edge == 2:
		return _run_buffalo_zero_respin(game, definition, run_state, environment, machine, seed_text)
	if mode == "free_games" and edge == 3:
		machine["bonus_reel_strips"] = _coin_heavy_reel_strips(maxi(1, int(machine.get("reel_count", 5))))
	return _run_buffalo_feature(game, definition, run_state, environment, machine, mode, edge == 4, seed_text)


func _run_pinball_headless(game: GameModule, definition: Dictionary, run_state: RunState, environment: Dictionary, machine: Dictionary, exact_cap: bool, label: String) -> Dictionary:
	var pinball := PinballScript.new()
	var active: Dictionary = pinball.open_feature(machine, 10, run_state.create_rng("open"), definition)
	active["headless"] = true
	if exact_cap:
		active["total_steps"] = 1
		active["balls_remaining"] = 1
		active["remaining_steps"] = 1
		active["session_cap"] = 1
		PinballFeatureScript.clear_runtime_session_cache()
	machine["active_bonus"] = active
	StateScript.write_machine(environment, "slot", machine)
	run_state.current_environment = environment
	var completed: Dictionary = _drive_feature(game, run_state, environment, label, "slot_bonus_launch", "")
	if not bool(completed.get("ok", false)):
		return completed
	if exact_cap and int(completed.get("award", 0)) > 1:
		return _fail(label, "pinball exact-cap run paid above cap")
	return _assert_base_surface(game, run_state, environment, label)


func _run_pinball_watchdog_save_load(game: GameModule, definition: Dictionary, run_state: RunState, environment: Dictionary, machine: Dictionary, label: String) -> Dictionary:
	var pinball := PinballScript.new()
	var active: Dictionary = pinball.open_feature(machine, 10, run_state.create_rng("open"), definition)
	active["total_steps"] = 1
	active["balls_remaining"] = 1
	active["remaining_steps"] = 1
	machine["active_bonus"] = active
	StateScript.write_machine(environment, "slot", machine)
	run_state.current_environment = environment
	var launch_rng: RngStream = run_state.create_rng("launch")
	var launch_result: Dictionary = game.resolve_with_context("slot_bonus_launch", 0, run_state, environment, launch_rng, {"surface_time_msec": 100, "drunk_scaled_surface_time_msec": 100})
	if bool(launch_result.get("ok", false)):
		GameModule.apply_result(run_state, launch_result, launch_rng)
	var launched_machine: Dictionary = StateScript.read_machine(environment, "slot")
	var launched_active: Dictionary = _dict(launched_machine.get("active_bonus", {}))
	launched_active["feature_total"] = maxi(19, int(launched_active.get("feature_total", 0)))
	launched_active["pending_award"] = maxi(19, int(launched_active.get("pending_award", 0)))
	launched_machine["active_bonus"] = launched_active
	StateScript.write_machine(environment, "slot", launched_machine)
	PinballFeatureScript.clear_runtime_session_cache()
	var restored: RunState = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	var restored_environment: Dictionary = _dict(restored.current_environment)
	restored.current_environment = restored_environment
	var watchdog: Dictionary = _drive_watchdog(game, restored, restored_environment, label)
	if not bool(watchdog.get("ok", false)):
		return watchdog
	if int(watchdog.get("award", 0)) < 19:
		return _fail(label, "pinball watchdog lost saved award")
	return _assert_base_surface(game, restored, restored_environment, label)


func _run_buffalo_zero_respin(game: GameModule, definition: Dictionary, run_state: RunState, environment: Dictionary, machine: Dictionary, label: String) -> Dictionary:
	var buffalo := BuffaloScript.new()
	var active: Dictionary = buffalo.open_feature(machine, {"classification": "hold_and_spin"}, 10, run_state.create_rng("open"), definition)
	active["remaining_steps"] = 0
	active["respins_remaining"] = 0
	active["feature_total"] = maxi(21, int(active.get("feature_total", 0)))
	active["pending_award"] = maxi(21, int(active.get("pending_award", 0)))
	machine["active_bonus"] = active
	StateScript.write_machine(environment, "slot", machine)
	run_state.current_environment = environment
	var completed: Dictionary = _drive_feature(game, run_state, environment, label, "slot_bonus_launch", "")
	if not bool(completed.get("ok", false)):
		return completed
	if int(completed.get("award", 0)) < 21:
		return _fail(label, "buffalo zero-respin run lost pending award")
	return _assert_base_surface(game, run_state, environment, label)


func _run_buffalo_feature(game: GameModule, definition: Dictionary, run_state: RunState, environment: Dictionary, machine: Dictionary, mode: String, save_load: bool, label: String) -> Dictionary:
	var buffalo := BuffaloScript.new()
	var active: Dictionary = buffalo.open_feature(machine, {"classification": mode}, 10, run_state.create_rng("open"), definition)
	if mode == "free_games" and _array(machine.get("bonus_reel_strips", [])).size() > 0:
		active["remaining_steps"] = 1
		active["total_steps"] = 1
		active["coins_since_retrigger"] = 2
	machine["active_bonus"] = active
	StateScript.write_machine(environment, "slot", machine)
	run_state.current_environment = environment
	var drive_run: RunState = run_state
	var drive_environment: Dictionary = environment
	if save_load:
		var restored: RunState = RunStateScript.new()
		restored.from_dict(run_state.to_dict())
		drive_run = restored
		drive_environment = _dict(restored.current_environment)
		restored.current_environment = drive_environment
	var desired_choice := "jackpot_boost" if mode == "monster_feature" else ""
	var completed: Dictionary = _drive_feature(game, drive_run, drive_environment, label, "slot_bonus_launch", desired_choice)
	if not bool(completed.get("ok", false)):
		return completed
	return _assert_base_surface(game, drive_run, drive_environment, label)


func _drive_feature(game: GameModule, run_state: RunState, environment: Dictionary, label: String, default_action: String, desired_choice_id: String) -> Dictionary:
	var rng: RngStream = run_state.create_rng("steps")
	var award := 0
	for guard in range(180):
		var machine: Dictionary = StateScript.read_machine(environment, "slot")
		if not StateScript.active_bonus_incomplete(machine):
			return {"ok": true, "award": award}
		var active: Dictionary = _dict(machine.get("active_bonus", {}))
		var action_id := _bonus_action_for(active, default_action, desired_choice_id)
		var result: Dictionary = game.resolve_with_context(action_id, 0, run_state, environment, rng, {})
		if bool(result.get("ok", false)):
			GameModule.apply_result(run_state, result, rng)
		award += int(result.get("bankroll_delta", 0))
	return _fail(label, "feature remained incomplete after guard")


func _drive_watchdog(game: GameModule, run_state: RunState, environment: Dictionary, label: String) -> Dictionary:
	var seed_time := 5000
	var seed_command: Dictionary = game.surface_auto_action_command({"surface_time_msec": seed_time, "drunk_scaled_surface_time_msec": seed_time}, run_state, environment, {})
	if not bool(seed_command.get("environment_changed", false)):
		return _fail(label, "watchdog did not arm")
	var due_time := seed_time + WATCHDOG_GRACE_MSEC + 200
	var command: Dictionary = game.surface_auto_action_command({"surface_time_msec": due_time, "drunk_scaled_surface_time_msec": due_time}, run_state, environment, {})
	if str(command.get("action_id", "")) != "slot_bonus_watchdog":
		return _fail(label, "watchdog did not route through bonus action")
	var rng: RngStream = run_state.create_rng("watchdog")
	var result: Dictionary = game.resolve_with_context(str(command.get("action_id", "")), 0, run_state, environment, rng, _dict(command.get("ui_state", {})))
	if bool(result.get("ok", false)):
		GameModule.apply_result(run_state, result, rng)
	return {"ok": bool(result.get("slot_bonus_complete", false)), "award": int(result.get("slot_bonus_award", 0)), "failure": "%s watchdog did not complete" % label}


func _assert_base_surface(game: GameModule, run_state: RunState, environment: Dictionary, label: String) -> Dictionary:
	var machine: Dictionary = StateScript.read_machine(environment, "slot")
	var active: Dictionary = _dict(machine.get("active_bonus", {}))
	if StateScript.active_bonus_incomplete(machine):
		return _fail(label, "active_bonus_incomplete true")
	if bool(active.get("active", false)) or not bool(active.get("complete", true)):
		return _fail(label, "active bonus sentinel not cleared")
	var surface_time := maxi(0, int(machine.get("slot_animation_duration_msec", 0))) + 700
	var surface: Dictionary = game.surface_state(run_state, environment, {"surface_time_msec": surface_time, "drunk_scaled_surface_time_msec": surface_time})
	var scene: Dictionary = _dict(surface.get("slot_feature_scene", {}))
	if bool(surface.get("slot_active_bonus_active", false)) or bool(scene.get("active", false)):
		return _fail(label, "surface did not return to base after replay elapsed")
	return {"ok": true}


func _bonus_action_for(active: Dictionary, fallback: String, desired_choice_id: String) -> String:
	if str(active.get("mode", "")) == "wheel":
		var choices: Array = _array(active.get("choices", []))
		for index in range(choices.size()):
			var choice: Dictionary = _dict(choices[index])
			if str(choice.get("id", "")) == desired_choice_id:
				if index == 0:
					return "slot_bonus_left"
				if index == 2:
					return "slot_bonus_right"
				return "slot_bonus_launch"
	return fallback


func _machine(definition: Dictionary, run_state: RunState, scenario: Dictionary) -> Dictionary:
	var generator := GeneratorScript.new()
	var machine: Dictionary = generator.build_machine_from_ids(definition, {
		"format_id": str(scenario.get("format", "")),
		"type_id": str(scenario.get("family", "")),
		"math_variant_id": "standard",
		"bonus_variant_id": str(scenario.get("bonus", "plain")),
		"cabinet_variant_id": "neon_magenta",
	}, run_state.create_rng("machine"))
	return StateScript.set_selected_bet(machine, "bet_10")


func _scenario_key(scenario: Dictionary) -> String:
	return "%s:%s:%s:%s" % [
		str(scenario.get("family", "")),
		str(scenario.get("format", "")),
		str(scenario.get("bonus", "")),
		str(scenario.get("mode", "")),
	]


func _coin_heavy_reel_strips(reel_count: int) -> Array:
	var strips: Array = []
	for _reel in range(maxi(1, reel_count)):
		strips.append(["GOLD_TOKEN", "BUFFALO", "GOLD_TOKEN", "SUNSET", "GOLD_TOKEN", "WOLF"])
	return strips


func _fixture_context(game_modules: Dictionary, game_id: String, label: String) -> Dictionary:
	var game: GameModule = game_modules.get(game_id, null) as GameModule
	if game == null:
		return {"ok": false, "failure": "%s missing game module %s" % [label, game_id]}
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(label)
	run_state.bankroll = 50000
	var environment := {
		"id": "%s_room" % label.to_lower().replace("-", "_"),
		"archetype_id": "grand_casino",
		"kind": "casino",
		"display_name": "SB6 Wait-State Room",
		"tier": 3,
		"game_ids": [game_id],
		"game_states": {},
		"economic_profile": {"stake_floor": 1, "stake_ceiling": 500, "cashout_tone": "test"},
		"security_profile": {"strictness": "loose"},
		"event_ids": [],
	}
	var state_rng: RngStream = run_state.create_rng("sb6_fixture_%s" % game_id)
	var game_states: Dictionary = {}
	game_states[game_id] = game.generate_environment_state(run_state, environment, state_rng)
	environment["game_states"] = game_states
	run_state.set_environment(environment)
	run_state.save_rng(state_rng)
	return {
		"ok": true,
		"game_id": game_id,
		"game": game,
		"run_state": run_state,
		"ui_state": {},
		"selected_action_id": "",
		"selected_action_kind": "",
		"stake": 10,
		"action_serial": 0,
	}


func _restore_context(context: Dictionary) -> void:
	var run_state: RunState = context.get("run_state", null) as RunState
	if run_state == null:
		return
	var restored: RunState = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	context["run_state"] = restored


func _surface_action(context: Dictionary, action: String, index: int, confirm_requested: bool, label: String) -> Dictionary:
	var game: GameModule = context.get("game", null) as GameModule
	var run_state: RunState = context.get("run_state", null) as RunState
	if game == null or run_state == null:
		return {"ok": false, "failure": "%s missing game/run for %s" % [label, action]}
	var command: Dictionary = game.surface_action_command(action, index, confirm_requested, _context_ui(context), run_state, run_state.current_environment)
	if command.is_empty() or not bool(command.get("handled", false)):
		return {"ok": false, "failure": "%s command %s was not handled" % [label, action]}
	return _apply_surface_command(context, command, label)


func _apply_surface_command(context: Dictionary, command: Dictionary, label: String) -> Dictionary:
	if command.has("ui_state") and typeof(command.get("ui_state")) == TYPE_DICTIONARY:
		context["ui_state"] = _dict(command.get("ui_state", {}))
	if command.has("set_stake"):
		context["stake"] = maxi(0, int(command.get("set_stake", context.get("stake", 10))))
	var action_id := str(command.get("action_id", ""))
	var action_kind := str(command.get("action_kind", ""))
	var direct_resolve := bool(command.get("direct_resolve", false)) and not action_id.is_empty()
	if not direct_resolve and not action_id.is_empty() and not action_kind.is_empty():
		var already_selected := str(context.get("selected_action_id", "")) == action_id and str(context.get("selected_action_kind", "")) == action_kind
		if not already_selected:
			context["selected_action_id"] = action_id
			context["selected_action_kind"] = action_kind
		if bool(command.get("resolve", false)) or already_selected:
			return _resolve_context_action(context, action_id, label, bool(command.get("preserve_surface_ui_state", false)))
	if direct_resolve:
		return _resolve_context_action(context, action_id, label, bool(command.get("preserve_surface_ui_state", false)))
	return {"ok": true}


func _resolve_context_action(context: Dictionary, action_id: String, label: String, preserve_surface_ui_state: bool) -> Dictionary:
	var game: GameModule = context.get("game", null) as GameModule
	var run_state: RunState = context.get("run_state", null) as RunState
	if game == null or run_state == null:
		return {"ok": false, "failure": "%s missing game/run for resolve %s" % [label, action_id]}
	var serial := int(context.get("action_serial", 0)) + 1
	context["action_serial"] = serial
	var rng: RngStream = run_state.create_rng("sb6_wait_%s_%03d" % [action_id, serial])
	var result: Dictionary = game.resolve_with_context(action_id, maxi(0, int(context.get("stake", 10))), run_state, run_state.current_environment, rng, _context_ui(context))
	if result.has("ui_state") and typeof(result.get("ui_state")) == TYPE_DICTIONARY:
		context["ui_state"] = _dict(result.get("ui_state", {}))
		preserve_surface_ui_state = bool(result.get("preserve_surface_ui_state", preserve_surface_ui_state))
	if not bool(result.get("ok", false)):
		return {"ok": false, "failure": "%s resolve %s failed: %s" % [label, action_id, str(result.get("message", "no message"))]}
	var runtime_tick := bool(result.get("slot_runtime_tick", false))
	var runtime_in_progress := runtime_tick and not bool(result.get("slot_bonus_complete", false))
	if not runtime_in_progress:
		run_state.advance_environment_turns(1)
	if bool(result.get("host_apply_result", false)) and not runtime_in_progress:
		GameModule.apply_result(run_state, result, rng)
	else:
		run_state.save_rng(rng)
	if not preserve_surface_ui_state:
		context["ui_state"] = {}
	context["selected_action_id"] = ""
	context["selected_action_kind"] = ""
	return {"ok": true, "result": result}


func _context_ui(context: Dictionary) -> Dictionary:
	var ui_state := _dict(context.get("ui_state", {}))
	ui_state["selected_action_id"] = str(context.get("selected_action_id", ""))
	ui_state["selected_action_kind"] = str(context.get("selected_action_kind", ""))
	ui_state["selected_stake"] = maxi(0, int(context.get("stake", 10)))
	return ui_state


func _game_state_from_context(context: Dictionary, game_id: String) -> Dictionary:
	var run_state: RunState = context.get("run_state", null) as RunState
	if run_state == null:
		return {}
	var states: Variant = run_state.current_environment.get("game_states", {})
	if typeof(states) != TYPE_DICTIONARY:
		return {}
	return _dict((states as Dictionary).get(game_id, {}))


func _write_game_state_to_context(context: Dictionary, game_id: String, state: Dictionary) -> void:
	var run_state: RunState = context.get("run_state", null) as RunState
	if run_state == null:
		return
	var states: Dictionary = run_state.current_environment.get("game_states", {}) if typeof(run_state.current_environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	states[game_id] = state.duplicate(true)
	run_state.current_environment["game_states"] = states


func _roulette_bet(stake: int) -> Dictionary:
	return {
		"id": "straight:17",
		"type": "straight",
		"numbers": ["17"],
		"stake": maxi(1, stake),
		"payout": 35,
		"label": "17",
		"family": "inside",
		"origin": "sb6_stuck_sweep",
		"placement": {"x": 480.0, "y": 190.0},
	}


func _scenario_ok(scenario: String) -> Dictionary:
	return {"ok": true, "scenario": scenario}


func _scenario_fail(scenario: String, label: String, reason: String) -> Dictionary:
	return {"ok": false, "scenario": scenario, "failure": "%s: %s" % [label, reason]}


func _ids(value: Variant) -> Array:
	var ids: Array = []
	for entry_value in _array(value):
		var entry: Dictionary = _dict(entry_value)
		var id := str(entry.get("id", ""))
		if not id.is_empty():
			ids.append(id)
	return ids


func _fail(label: String, reason: String) -> Dictionary:
	return {"ok": false, "failure": "%s: %s" % [label, reason]}


func _dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


func _array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)
