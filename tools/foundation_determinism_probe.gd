extends SceneTree

# End-to-end seeded determinism probe. The PowerShell wrapper runs this script
# twice in separate Godot processes and compares every checkpoint hash.

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const WorldMapScript := preload("res://scripts/core/world_map.gd")

const DEFAULT_SEED_COUNT := 10
const DEFAULT_SEED_PREFIX := "FOUNDATION-DETERMINISM"
const DEFAULT_OUTPUT_JSON := "res://.tmp/foundation_determinism_probe/report.json"
const GAME_IDS := ["slot", "pull_tabs", "scratch_tickets", "blackjack", "baccarat", "roulette", "video_poker", "bar_dice"]
const HASH_MOD := 4294967296

var library: ContentLibrary
var generator: RunGenerator
var game_modules: Dictionary = {}
var failures: Array = []
var warnings: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var seed_count := maxi(1, int(OS.get_environment("BTH_DETERMINISM_SEED_COUNT")))
	if seed_count <= 1 and OS.get_environment("BTH_DETERMINISM_SEED_COUNT").strip_edges().is_empty():
		seed_count = DEFAULT_SEED_COUNT
	var seed_prefix := OS.get_environment("BTH_DETERMINISM_SEED_PREFIX").strip_edges()
	if seed_prefix.is_empty():
		seed_prefix = DEFAULT_SEED_PREFIX
	var output_json := OS.get_environment("BTH_DETERMINISM_OUTPUT").strip_edges()
	if output_json.is_empty():
		output_json = DEFAULT_OUTPUT_JSON

	library = ContentLibraryScript.new()
	library.load()
	for error_value in library.validation_errors:
		failures.append("Content validation error: %s" % str(error_value))
	for warning_value in library.validation_warnings:
		warnings.append("Content validation warning: %s" % str(warning_value))
	generator = RunGeneratorScript.new(library)
	_build_game_modules()

	var runs: Array = []
	for seed_index in range(seed_count):
		var seed := "%s-%03d" % [seed_prefix, seed_index + 1]
		runs.append(_simulate_seed(seed, seed_index))

	var checkpoint_rows: Array = []
	for run_value in runs:
		var run: Dictionary = run_value
		for checkpoint_value in _dictionary_array(run.get("checkpoints", [])):
			checkpoint_rows.append(checkpoint_value)
	var combined_hash := _stable_hash_text(_canonical_text(checkpoint_rows))
	var report := {
		"tool": "foundation_determinism_probe",
		"deterministic": true,
		"seed_prefix": seed_prefix,
		"seed_count": seed_count,
		"checkpoint_count": checkpoint_rows.size(),
		"combined_hash": combined_hash,
		"passed": failures.is_empty(),
		"runs": runs,
		"failures": failures,
		"warnings": warnings,
	}
	_write_json(output_json, report)
	_print_summary(report, output_json)
	await _finish(0 if failures.is_empty() else 1)


func _finish(exit_code: int) -> void:
	await process_frame
	quit(exit_code)


func _build_game_modules() -> void:
	game_modules = {}
	for game_value in library.games:
		if typeof(game_value) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = game_value
		var game_id := str(definition.get("id", "")).strip_edges()
		if game_id.is_empty():
			continue
		var game := _create_game_module(definition)
		if game != null:
			game_modules[game_id] = game
	for required_id in GAME_IDS:
		if not game_modules.has(required_id):
			failures.append("Missing game module for determinism probe: %s" % required_id)


func _create_game_module(definition: Dictionary) -> GameModule:
	var module_path := str(definition.get("module_path", "")).strip_edges()
	if module_path.is_empty() or module_path.ends_with("_ui.gd") or module_path.begins_with("res://data/runtime/"):
		return null
	var module_script: Script = load(module_path)
	if module_script == null:
		failures.append("Could not load game module script: %s" % module_path)
		return null
	var module_instance: Object = module_script.new()
	if not module_instance is GameModule:
		failures.append("Game module script did not create GameModule: %s" % module_path)
		return null
	var game: GameModule = module_instance
	game.setup(definition, library)
	return game


func _simulate_seed(seed: String, seed_index: int) -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed, RunStateScript.standard_challenge(seed))
	run_state.bankroll = 20000
	var checkpoints: Array = []

	generator.next_environment(run_state)
	_checkpoint(run_state, checkpoints, seed, "world_map_generation")
	_apply_alcohol_timing(run_state, checkpoints, seed)
	_apply_world_travel(run_state, checkpoints, seed)
	_apply_triggered_event_chain(run_state, checkpoints, seed)
	_apply_dialogue_sequence(run_state, checkpoints, seed)
	_apply_talk_content_sequence(run_state, checkpoints, seed)
	_install_all_game_environment(run_state, seed_index)
	_checkpoint(run_state, checkpoints, seed, "all_games_fixture")
	_apply_all_game_resolves(run_state, checkpoints, seed)
	_apply_skill_cheats(run_state, checkpoints, seed)
	_apply_pinball_feature_sequence(run_state, checkpoints, seed)
	return {
		"seed": seed,
		"checkpoint_count": checkpoints.size(),
		"final_hash": str((checkpoints.back() as Dictionary).get("hash", "")) if not checkpoints.is_empty() else "",
		"checkpoints": checkpoints,
	}


func _apply_alcohol_timing(run_state: RunState, checkpoints: Array, seed: String) -> void:
	run_state.drink_alcohol(6)
	_checkpoint(run_state, checkpoints, seed, "alcohol_absorption_queued")
	run_state.advance_environment_turns(1)
	run_state.update_drunk_absorption()
	_checkpoint(run_state, checkpoints, seed, "alcohol_absorption_applied")


func _apply_world_travel(run_state: RunState, checkpoints: Array, seed: String) -> void:
	if not run_state.has_world_map():
		failures.append("%s did not build a world map." % seed)
		return
	var source_id := run_state.current_world_node_id()
	var target_ids := WorldMapScript.travel_target_ids(run_state.world_map, source_id)
	if target_ids.is_empty():
		failures.append("%s has no visible world-map travel targets." % seed)
		return
	var target_id := str(target_ids[0])
	var route := generator.world_route_for_target(run_state, target_id)
	if route.is_empty():
		failures.append("%s could not build route to %s." % [seed, target_id])
		return
	var previous_environment := run_state.current_environment.duplicate(true)
	var route_risk := run_state.travel_route_risk(route, target_id)
	var travel_heat := run_state.begin_travel_suspicion_decay(route, target_id)
	generator.next_environment(run_state, target_id)
	var travel_decay := run_state.finish_travel_suspicion_decay(travel_heat)
	var result := _travel_result(target_id, previous_environment, run_state.current_environment, route, travel_decay, route_risk)
	GameModule.apply_result(run_state, result)
	run_state.advance_environment_turns(1)
	_checkpoint(run_state, checkpoints, seed, "world_map_travel_risk")


func _apply_triggered_event_chain(run_state: RunState, checkpoints: Array, seed: String) -> void:
	var phone_event := _event_module("call_brother_in_law")
	if phone_event == null:
		return
	run_state.current_environment["event_ids"] = _unique_strings(_string_array(run_state.current_environment.get("event_ids", [])) + ["call_brother_in_law"])
	phone_event.resolve(run_state, run_state.current_environment, "make_call")
	run_state.advance_environment_turns(1)
	_checkpoint(run_state, checkpoints, seed, "triggered_event_queued")
	var pending := run_state.next_pending_triggered_event()
	if not pending.is_empty():
		run_state.begin_triggered_event_resolution(pending)
		_checkpoint(run_state, checkpoints, seed, "triggered_event_active")
	var family_event := _event_module("family_loan")
	if family_event == null:
		return
	family_event.resolve(run_state, run_state.current_environment, "deny")
	run_state.complete_triggered_event_resolution("family_loan")
	run_state.advance_environment_turns(1)
	_checkpoint(run_state, checkpoints, seed, "triggered_event_resolved")


func _apply_dialogue_sequence(run_state: RunState, checkpoints: Array, seed: String) -> void:
	var dialogue := library.dialogue("pull_tab_clerk")
	if dialogue.is_empty():
		failures.append("Missing dialogue definition for determinism probe: pull_tab_clerk")
		return
	var speaker: Dictionary = dialogue.get("speaker", {}) if typeof(dialogue.get("speaker", {})) == TYPE_DICTIONARY else {}
	if not run_state.enqueue_dialogue("pull_tab_clerk", "dialogue:pull_tab_clerk", speaker, str(dialogue.get("start", "greeting")), "determinism", {"trigger": "dialogue"}):
		failures.append("%s could not enqueue dialogue determinism fixture." % seed)
		return
	_checkpoint(run_state, checkpoints, seed, "dialogue_queued")
	var route_effects := _dialogue_choice_effects(dialogue, "greeting", "ask_routes")
	if route_effects.is_empty():
		failures.append("Missing ask_routes dialogue fixture for determinism probe.")
		return
	var route_event := _dialogue_event("dialogue_route_determinism", "ask_routes", route_effects)
	route_event.resolve(run_state, run_state.current_environment, "ask_routes")
	run_state.update_pending_talk_dialogue_node("dialogue:pull_tab_clerk", "routes")
	_checkpoint(run_state, checkpoints, seed, "dialogue_route_choice")
	var loose_effects := _dialogue_choice_effects(dialogue, "greeting", "ask_loose")
	if loose_effects.is_empty():
		failures.append("Missing ask_loose dialogue fixture for determinism probe.")
		return
	var loose_event := _dialogue_event("dialogue_loose_determinism", "ask_loose", loose_effects)
	loose_event.resolve(run_state, run_state.current_environment, "ask_loose")
	run_state.complete_talk_event_resolution("dialogue:pull_tab_clerk")
	_checkpoint(run_state, checkpoints, seed, "dialogue_risky_choice")


func _dialogue_choice_effects(dialogue: Dictionary, node_id: String, choice_id: String) -> Dictionary:
	var nodes: Dictionary = dialogue.get("nodes", {}) if typeof(dialogue.get("nodes", {})) == TYPE_DICTIONARY else {}
	var node: Dictionary = nodes.get(node_id, {}) if typeof(nodes.get(node_id, {})) == TYPE_DICTIONARY else {}
	var choices: Array = node.get("choices", []) if typeof(node.get("choices", [])) == TYPE_ARRAY else []
	for choice_value in choices:
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = choice_value
		if str(choice.get("id", "")) != choice_id:
			continue
		var effects: Dictionary = choice.get("effects", {}) if typeof(choice.get("effects", {})) == TYPE_DICTIONARY else {}
		return effects.duplicate(true)
	return {}


func _dialogue_event(event_id: String, choice_id: String, effects: Dictionary) -> EventModule:
	var event := EventModuleScript.new()
	event.setup({
		"id": event_id,
		"display_name": "Dialogue Determinism",
		"type": "social",
		"interaction_mode": "triggered",
		"scopes": ["any"],
		"trigger": {"type": "manual"},
		"payload": {
			"choices": [{
				"id": choice_id,
				"label": choice_id,
				"text": choice_id,
				"consequences": effects,
			}],
		},
	}, library)
	return event


func _apply_talk_content_sequence(run_state: RunState, checkpoints: Array, seed: String) -> void:
	run_state.add_suspicion("talk_content_probe", 90, "behavior")
	for spec_value in [
		{"event_id": "blackjack_counter_probe", "choice_id": "play_dumb", "trigger": "table_approach", "game_id": "blackjack"},
		{"event_id": "floor_staff_heat_warning", "choice_id": "buy_round", "trigger": "heat_threshold", "threshold": 65},
		{"event_id": "pit_boss_heat_warning", "choice_id": "bluff", "trigger": "heat_threshold", "threshold": 85},
		{"event_id": "suspicious_patron", "choice_id": "talk_down", "trigger": "timed"},
	]:
		var spec: Dictionary = spec_value
		var event_id := str(spec.get("event_id", ""))
		var choice_id := str(spec.get("choice_id", ""))
		var event_definition := library.event(event_id)
		if event_definition.is_empty():
			failures.append("Missing talk content determinism event: %s" % event_id)
			continue
		var context := {
			"trigger": str(spec.get("trigger", "talk_content")),
			"type": str(spec.get("trigger", "talk_content")),
			"game_id": str(spec.get("game_id", "")),
			"threshold": int(spec.get("threshold", 0)),
			"hands_played": 2,
		}
		var speaker: Dictionary = event_definition.get("speaker", {}) if typeof(event_definition.get("speaker", {})) == TYPE_DICTIONARY else {}
		if not run_state.enqueue_triggered_event(event_id, "talk_content_determinism", context, {"presentation": "talk", "speaker": speaker}):
			failures.append("%s could not enqueue talk content event %s." % [seed, event_id])
			continue
		_checkpoint(run_state, checkpoints, seed, "talk_content_%s_queued" % event_id)
		var event_module := _event_module(event_id)
		if event_module == null:
			continue
		event_module.resolve(run_state, run_state.current_environment, choice_id)
		run_state.complete_talk_event_resolution(event_id)
		_checkpoint(run_state, checkpoints, seed, "talk_content_%s_resolved" % event_id)


func _install_all_game_environment(run_state: RunState, seed_index: int) -> void:
	var environment := run_state.current_environment.duplicate(true)
	environment["id"] = "determinism_room_%02d" % seed_index
	environment["display_name"] = "Determinism Room"
	environment["archetype_id"] = "grand_casino"
	environment["kind"] = "boss"
	environment["tier"] = 3
	environment["game_ids"] = GAME_IDS.duplicate()
	environment["travel_lock_remaining"] = 0
	environment["economic_profile"] = {
		"stake_floor": 1,
		"stake_ceiling": 500,
	}
	var game_states: Dictionary = {}
	var fixture_rng := run_state.create_rng("determinism_game_fixture")
	for game_id_value in GAME_IDS:
		var game_id := str(game_id_value)
		var game: GameModule = game_modules.get(game_id, null)
		if game == null:
			continue
		var state_rng: RngStream = fixture_rng.fork("state:%s" % game_id)
		game_states[game_id] = game.generate_environment_state(run_state, environment, state_rng)
	environment["game_states"] = game_states
	run_state.set_environment(environment)
	run_state.save_rng(fixture_rng)
	run_state.bankroll = maxi(run_state.bankroll, 20000)
	run_state.grand_casino_chips = 0
	var buy_in := run_state.buy_grand_casino_chips(10000, run_state.grand_casino_chip_exchange_rate())
	if not bool(buy_in.get("ok", false)):
		failures.append("Determinism fixture could not buy Grand Casino chips: %s" % str(buy_in.get("message", "no message")))


func _apply_all_game_resolves(run_state: RunState, checkpoints: Array, seed: String) -> void:
	_resolve_game(run_state, checkpoints, seed, "slot", "spin", 0, _timed_ui(run_state, "slot_spin"))
	_resolve_game(run_state, checkpoints, seed, "pull_tabs", "buy_tab", 0, _timed_ui(run_state, "pull_tabs_buy", {"pull_tab_deal_index": 0}))
	_resolve_game(run_state, checkpoints, seed, "scratch_tickets", "buy_scratch_ticket", 2, _timed_ui(run_state, "scratch_ticket_buy", {"scratch_stock_index": 0}))
	_resolve_game(run_state, checkpoints, seed, "blackjack", "play_basic", 20, _timed_ui(run_state, "blackjack_play", {"selected_stake": 20}))
	_resolve_game(run_state, checkpoints, seed, "baccarat", "deal_baccarat", 20, _timed_ui(run_state, "baccarat_deal", {"baccarat_bets": {"player": 20}}))
	_resolve_game(run_state, checkpoints, seed, "roulette", "spin_roulette", 20, _timed_ui(run_state, "roulette_spin", {"roulette_bets": [_roulette_bet(20)]}))
	_resolve_game(run_state, checkpoints, seed, "video_poker", "draw", 0, _timed_ui(run_state, "video_poker_draw", {"bet_level": 1, "denomination_index": 0}))
	_resolve_game(run_state, checkpoints, seed, "bar_dice", "roll", 20, _timed_ui(run_state, "bar_dice_roll"))


func _apply_skill_cheats(run_state: RunState, checkpoints: Array, seed: String) -> void:
	_resolve_blackjack_count(run_state, checkpoints, seed)
	_resolve_video_poker_holdout(run_state, checkpoints, seed)
	_resolve_bar_dice_controlled_roll(run_state, checkpoints, seed)
	_resolve_roulette_past_post(run_state, checkpoints, seed)
	_resolve_baccarat_edge_sort(run_state, checkpoints, seed)


func _apply_pinball_feature_sequence(run_state: RunState, checkpoints: Array, seed: String) -> void:
	var slot: GameModule = game_modules.get("slot", null)
	if slot == null:
		return
	var environment := run_state.current_environment
	var game_states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var machine: Dictionary = game_states.get("slot", {}) if typeof(game_states.get("slot", {})) == TYPE_DICTIONARY else {}
	if machine.is_empty():
		return
	machine["type_id"] = "pinball"
	machine["active_bonus"] = {
		"active": true,
		"complete": false,
		"family": "pinball",
		"balls_remaining": 1,
		"score": 0,
	}
	game_states["slot"] = machine
	environment["game_states"] = game_states
	var commands := [
		"pinball_flipper_left",
		"pinball_flipper_right",
		"pinball_skill_shot",
		"pinball_nudge_left",
	]
	var ui_state := _timed_ui(run_state, "pinball_feature")
	for command_value in commands:
		var command_id := str(command_value)
		ui_state["surface_time_msec"] = int(ui_state.get("surface_time_msec", 0)) + 133
		var command := slot.surface_action_command(command_id, 0, false, ui_state, run_state, environment)
		if typeof(command.get("ui_state", {})) == TYPE_DICTIONARY:
			ui_state = command.get("ui_state", {}) as Dictionary
	_checkpoint(run_state, checkpoints, seed, "pinball_feature_inputs")


func _resolve_blackjack_count(run_state: RunState, checkpoints: Array, seed: String) -> void:
	var game: GameModule = game_modules.get("blackjack", null)
	if game == null:
		return
	var ui_state := _timed_ui(run_state, "blackjack_count", {"selected_stake": 20})
	var result := _resolve_game(run_state, checkpoints, seed, "blackjack", "count_cards", 0, ui_state, false)
	if bool(result.get("ok", false)):
		run_state.advance_environment_turns(1)
	_checkpoint(run_state, checkpoints, seed, "skill_blackjack_count_cards")


func _resolve_video_poker_holdout(run_state: RunState, checkpoints: Array, seed: String) -> void:
	var game: GameModule = game_modules.get("video_poker", null)
	if game == null:
		return
	var ui_state := _timed_ui(run_state, "video_poker_holdout", {"bet_level": 1, "denomination_index": 0})
	var deal_command: Dictionary = game.surface_action_command("video_poker_deal", 0, false, ui_state, run_state, run_state.current_environment)
	ui_state = _copy_dict(deal_command.get("ui_state", ui_state))
	ui_state["surface_time_msec"] = int(ui_state.get("surface_time_msec", run_state.simulation_time_msec())) + 600
	var mark_command: Dictionary = game.surface_action_command("video_poker_mark", 0, false, ui_state, run_state, run_state.current_environment)
	ui_state = _copy_dict(mark_command.get("ui_state", ui_state))
	var challenge: Dictionary = _copy_dict(ui_state.get("holdout_challenge", {}))
	ui_state["holdout_input_msec"] = int(challenge.get("perfect_msec", ui_state.get("surface_time_msec", 0)))
	ui_state["surface_time_msec"] = int(ui_state["holdout_input_msec"])
	var palm_command: Dictionary = game.surface_action_command("video_poker_palm", 0, false, ui_state, run_state, run_state.current_environment)
	ui_state = _copy_dict(palm_command.get("ui_state", ui_state))
	var result := _resolve_game(run_state, checkpoints, seed, "video_poker", "mark_holds", 0, ui_state, false)
	if bool(result.get("ok", false)):
		run_state.advance_environment_turns(1)
	_checkpoint(run_state, checkpoints, seed, "skill_video_poker_holdout")


func _resolve_bar_dice_controlled_roll(run_state: RunState, checkpoints: Array, seed: String) -> void:
	var game: GameModule = game_modules.get("bar_dice", null)
	if game == null:
		return
	var ui_state := _timed_ui(run_state, "bar_dice_controlled_roll")
	var roll_command: Dictionary = game.surface_action_command("bar_dice_roll", 0, false, ui_state, run_state, run_state.current_environment)
	ui_state = _copy_dict(roll_command.get("ui_state", ui_state))
	var challenge: Dictionary = _copy_dict(ui_state.get("controlled_roll", {}))
	ui_state["controlled_roll_input_msec"] = int(challenge.get("target_msec", ui_state.get("surface_time_msec", 0)))
	ui_state["surface_time_msec"] = int(ui_state["controlled_roll_input_msec"])
	var result := _resolve_game(run_state, checkpoints, seed, "bar_dice", "loaded_toss", 20, ui_state, false)
	if bool(result.get("ok", false)):
		run_state.advance_environment_turns(1)
	_checkpoint(run_state, checkpoints, seed, "skill_bar_dice_controlled_roll")


func _resolve_roulette_past_post(run_state: RunState, checkpoints: Array, seed: String) -> void:
	var game: GameModule = game_modules.get("roulette", null)
	if game == null:
		return
	var spin_ui := _timed_ui(run_state, "roulette_past_spin", {"roulette_bets": [_roulette_bet(20)]})
	var spin_result := _resolve_game(run_state, checkpoints, seed, "roulette", "spin_roulette", 20, spin_ui, false)
	if bool(spin_result.get("ok", false)):
		run_state.advance_environment_turns(1)
	var table: Dictionary = _game_state(run_state, "roulette")
	var last_result: Dictionary = _copy_dict(table.get("last_result", {}))
	var payout_ui := _timed_ui(run_state, "roulette_past_post")
	payout_ui["surface_time_msec"] = int(last_result.get("resolved_at_msec", payout_ui.get("surface_time_msec", 0))) + 3050
	var arm_command: Dictionary = game.surface_action_command("roulette_past_post", 0, false, payout_ui, run_state, run_state.current_environment)
	var ui_state := _copy_dict(arm_command.get("ui_state", payout_ui))
	var challenge: Dictionary = _copy_dict(ui_state.get("past_post_challenge", {}))
	ui_state["past_post_input_msec"] = int(challenge.get("window_start_msec", ui_state.get("surface_time_msec", 0)))
	ui_state["surface_time_msec"] = int(ui_state["past_post_input_msec"])
	var result := _resolve_game(run_state, checkpoints, seed, "roulette", "past_post", 20, ui_state, false)
	if bool(result.get("ok", false)):
		run_state.advance_environment_turns(1)
	_checkpoint(run_state, checkpoints, seed, "skill_roulette_past_post")


func _resolve_baccarat_edge_sort(run_state: RunState, checkpoints: Array, seed: String) -> void:
	var game: GameModule = game_modules.get("baccarat", null)
	if game == null:
		return
	var game_states: Dictionary = run_state.current_environment.get("game_states", {}) if typeof(run_state.current_environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	game_states["baccarat"] = game.generate_environment_state(run_state, run_state.current_environment, run_state.create_rng("determinism_baccarat_edge_state"))
	run_state.current_environment["game_states"] = game_states
	var ui_state := _timed_ui(run_state, "baccarat_edge_sort")
	var start_command: Dictionary = game.surface_action_command("baccarat_edge_sort", 0, false, ui_state, run_state, run_state.current_environment)
	if not bool(start_command.get("handled", false)):
		failures.append("%s baccarat edge-sort command did not start." % seed)
		return
	var observe_ui := _timed_ui(run_state, "baccarat_edge_observe", {"baccarat_sit_out": true})
	var ready_challenge: Dictionary = {}
	for index in range(4):
		observe_ui["surface_time_msec"] = int(observe_ui.get("surface_time_msec", 0)) + index * 400
		var observe_result := _resolve_game(run_state, checkpoints, seed, "baccarat", "deal_baccarat", 20, observe_ui, false)
		if bool(observe_result.get("ok", false)):
			run_state.advance_environment_turns(1)
		var observed_table: Dictionary = _game_state(run_state, "baccarat")
		var observed_challenge: Dictionary = _copy_dict(observed_table.get("edge_sort_challenge", {}))
		if bool(observed_challenge.get("ready", false)):
			ready_challenge = observed_challenge
			break
	var table: Dictionary = _game_state(run_state, "baccarat")
	if ready_challenge.is_empty():
		ready_challenge = _copy_dict(table.get("edge_sort_challenge", {}))
	if ready_challenge.is_empty() or not bool(ready_challenge.get("ready", false)):
		failures.append("%s baccarat edge-sort challenge did not become ready." % seed)
		_checkpoint(run_state, checkpoints, seed, "skill_baccarat_edge_sort")
		return
	var result := _resolve_game(run_state, checkpoints, seed, "baccarat", "edge_sort", 0, {"edge_sort_challenge": ready_challenge, "edge_sort_answer_mode": "perfect"}, false)
	if bool(result.get("ok", false)):
		run_state.advance_environment_turns(1)
	_checkpoint(run_state, checkpoints, seed, "skill_baccarat_edge_sort")


func _resolve_game(run_state: RunState, checkpoints: Array, seed: String, game_id: String, action_id: String, stake: int, ui_state: Dictionary, auto_apply: bool = true) -> Dictionary:
	var game: GameModule = game_modules.get(game_id, null)
	if game == null:
		failures.append("%s missing game %s for %s." % [seed, game_id, action_id])
		return {}
	var rng := run_state.create_rng("determinism:%s:%s:%d" % [game_id, action_id, checkpoints.size()])
	var result: Dictionary = game.resolve_with_context(action_id, stake, run_state, run_state.current_environment, rng, ui_state)
	if not bool(result.get("ok", false)):
		failures.append("%s %s/%s failed: %s" % [seed, game_id, action_id, str(result.get("message", "no message"))])
		return result
	if auto_apply:
		_apply_game_result(run_state, result, rng)
		if not bool(result.get("slot_runtime_tick", false)):
			run_state.advance_environment_turns(1)
		_checkpoint(run_state, checkpoints, seed, "game_%s_%s" % [game_id, action_id])
	return result


func _apply_game_result(run_state: RunState, result: Dictionary, rng: RngStream) -> void:
	if result.is_empty() or not bool(result.get("ok", false)):
		return
	if bool(result.get("host_apply_result", false)):
		GameModule.apply_result(run_state, result, rng)
	else:
		run_state.save_rng(rng)


func _checkpoint(run_state: RunState, checkpoints: Array, seed: String, label: String) -> void:
	var canonical := _canonical_text(run_state.to_dict())
	checkpoints.append({
		"seed": seed,
		"index": checkpoints.size(),
		"label": label,
		"hash": _stable_hash_text(canonical),
		"bytes": canonical.length(),
	})


func _timed_ui(run_state: RunState, key: String, extras: Dictionary = {}) -> Dictionary:
	var ui_state := extras.duplicate(true)
	ui_state["surface_time_msec"] = run_state.simulation_time_msec() + 10000 + int(_stable_hash_text("%s:%s" % [run_state.seed_text, key])) % 60000
	ui_state["drunk_scaled_surface_time_msec"] = ui_state["surface_time_msec"]
	return ui_state


func _travel_result(target_id: String, previous_environment: Dictionary, destination_environment: Dictionary, route: Dictionary, travel_decay: Dictionary, route_risk: Dictionary) -> Dictionary:
	var status := run_state_route_status_placeholder(route)
	var cost := int(status.get("cost", route.get("cost", 0)))
	var suspicion_delta := int(status.get("suspicion_delta", route.get("suspicion_delta", 0)))
	var risk_bankroll_delta := int(route_risk.get("bankroll_delta", 0)) if bool(route_risk.get("triggered", false)) else 0
	var risk_suspicion_delta := int(route_risk.get("suspicion_delta", 0)) if bool(route_risk.get("triggered", false)) else 0
	var total_bankroll_delta := -cost + risk_bankroll_delta
	var total_suspicion_delta := suspicion_delta + risk_suspicion_delta
	var destination_name := str(destination_environment.get("display_name", target_id.replace("_", " ").capitalize()))
	var message := "Determinism travel to %s." % destination_name
	var story_entries: Array = [{
		"type": "travel",
		"id": target_id,
		"route_id": target_id,
		"from_environment_id": str(previous_environment.get("id", "")),
		"from_environment_name": str(previous_environment.get("display_name", "")),
		"to_archetype_id": target_id,
		"to_environment_id": str(destination_environment.get("id", "")),
		"to_environment_name": destination_name,
		"bankroll_delta": total_bankroll_delta,
		"route_cost": cost,
		"suspicion_delta": total_suspicion_delta,
		"risk_decay": int(travel_decay.get("risk_decay", status.get("risk_decay", 0))),
		"route_risk": route_risk.duplicate(true),
		"drunk_delta": int(travel_decay.get("drunk_delta", 0)),
		"message": message,
	}]
	if bool(route_risk.get("triggered", false)):
		story_entries.append({
			"type": "travel_risk_event",
			"id": str(route_risk.get("id", "travel_risk")),
			"route_id": target_id,
			"label": str(route_risk.get("label", "Route risk")),
			"roll": int(route_risk.get("roll", 0)),
			"chance_percent": int(route_risk.get("chance_percent", 0)),
			"bankroll_delta": risk_bankroll_delta,
			"suspicion_delta": risk_suspicion_delta,
			"message": str(route_risk.get("message", "")),
		})
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = total_bankroll_delta
	deltas["suspicion_delta"] = total_suspicion_delta
	deltas["story_log"] = story_entries
	deltas["messages"] = [message]
	return GameModule.build_action_result({
		"ok": true,
		"type": "travel",
		"source_id": target_id,
		"action_id": "confirm_travel",
		"action_kind": "travel",
		"environment_id": str(destination_environment.get("id", "")),
		"environment_archetype_id": target_id,
		"bankroll_delta": total_bankroll_delta,
		"suspicion_delta": total_suspicion_delta,
		"route_cost": cost,
		"route_risk": route_risk.duplicate(true),
		"deltas": deltas,
		"message": message,
	})


func run_state_route_status_placeholder(route: Dictionary) -> Dictionary:
	return route.duplicate(true)


func _event_module(event_id: String) -> EventModule:
	var event_definition := library.event(event_id)
	if event_definition.is_empty():
		failures.append("Missing event definition for determinism probe: %s" % event_id)
		return null
	var event_module := EventModuleScript.new()
	event_module.setup(event_definition, library)
	return event_module


func _game_state(run_state: RunState, game_id: String) -> Dictionary:
	var game_states: Dictionary = run_state.current_environment.get("game_states", {}) if typeof(run_state.current_environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	return game_states.get(game_id, {}) if typeof(game_states.get(game_id, {})) == TYPE_DICTIONARY else {}


func _roulette_bet(stake: int) -> Dictionary:
	return {
		"id": "red",
		"type": "red",
		"family": "outside",
		"numbers": ["1", "3", "5", "7", "9", "12", "14", "16", "18", "19", "21", "23", "25", "27", "30", "32", "34", "36"],
		"stake": maxi(1, stake),
		"payout": 1,
		"label": "RED",
	}


func _write_json(path: String, report: Dictionary) -> void:
	var directory := path.get_base_dir()
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write determinism report: %s" % path)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()


func _print_summary(report: Dictionary, output_json: String) -> void:
	print("FOUNDATION_DETERMINISM_PROBE passed=%s seeds=%d checkpoints=%d hash=%s output=%s" % [
		str(bool(report.get("passed", false))),
		int(report.get("seed_count", 0)),
		int(report.get("checkpoint_count", 0)),
		str(report.get("combined_hash", "")),
		output_json,
	])
	for failure_value in failures:
		push_error(str(failure_value))


func _canonical_text(value: Variant) -> String:
	match typeof(value):
		TYPE_DICTIONARY:
			var source: Dictionary = value
			var keys: Array = source.keys()
			keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
			var parts: Array = []
			for key_value in keys:
				parts.append("%s:%s" % [JSON.stringify(str(key_value)), _canonical_text(source[key_value])])
			return "{%s}" % ",".join(parts)
		TYPE_ARRAY:
			var array_value: Array = value
			var parts: Array = []
			for item_value in array_value:
				parts.append(_canonical_text(item_value))
			return "[%s]" % ",".join(parts)
		TYPE_FLOAT:
			return "%.8f" % float(value)
		_:
			return JSON.stringify(value)


func _stable_hash_text(text: String) -> String:
	var hash_value := 2166136261
	for index in range(text.length()):
		hash_value = int((hash_value ^ text.unicode_at(index)) % HASH_MOD)
		hash_value = int((hash_value * 16777619) % HASH_MOD)
	return str(hash_value)


func _copy_dict(value: Variant) -> Dictionary:
	return value.duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item_value in value:
		if typeof(item_value) == TYPE_DICTIONARY:
			result.append((item_value as Dictionary).duplicate(true))
	return result


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item_value in value:
		var text := str(item_value).strip_edges()
		if not text.is_empty():
			result.append(text)
	return result


func _unique_strings(values: Array) -> Array:
	var result: Array = []
	for value in _string_array(values):
		if not result.has(value):
			result.append(value)
	return result
