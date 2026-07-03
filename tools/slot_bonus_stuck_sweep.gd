extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const SlotGameScript := preload("res://scripts/games/slot.gd")
const GeneratorScript := preload("res://scripts/games/slots/slot_machine_generator.gd")
const StateScript := preload("res://scripts/games/slots/slot_machine_state.gd")
const BuffaloScript := preload("res://scripts/games/slots/slot_family_buffalo.gd")
const PinballScript := preload("res://scripts/games/slots/slot_family_pinball.gd")
const PinballFeatureScript := preload("res://scripts/games/slots/pinball/pinball_feature.gd")

const WATCHDOG_GRACE_MSEC := 2200


func _init() -> void:
	var seed_count := _seed_count()
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	var definition: Dictionary = library.game("slot")
	var game: GameModule = SlotGameScript.new()
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
	if failures.is_empty():
		print("SLOT_BONUS_STUCK_SWEEP status=PASS seeds=%d scenarios=%d stuck=0 counts=%s" % [seed_count, scenarios.size(), JSON.stringify(counts)])
		quit(0)
		return
	var shown: Array = failures.slice(0, mini(20, failures.size()))
	print("SLOT_BONUS_STUCK_SWEEP status=FAIL seeds=%d failures=%d details=%s" % [seed_count, failures.size(), JSON.stringify(shown)])
	quit(1)


func _seed_count() -> int:
	var seeds := 200
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
