extends SceneTree

# Deterministic Act 1 balance probe. It drives RunState, RunGenerator,
# RunActionService, EventModule, and GameModule paths directly so the reported
# economy/endgame metrics stay close to production behavior without requiring UI.

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const RunActionServiceScript := preload("res://scripts/core/run_action_service.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const WorldMapScript := preload("res://scripts/core/world_map.gd")

const DEFAULT_SEEDS_PER_SCENARIO := 2
const DEFAULT_SEED_PREFIX := "ACT1-BALANCE"
const DEFAULT_OUTPUT_JSON := "res://.tmp/endgame_metrics_probe/report.json"
const DEFAULT_OUTPUT_MARKDOWN := "res://.tmp/endgame_metrics_probe/report.md"
const MAX_ACTIONS := 88
const GAME_ACTION_SECONDS := 69.0
const TRAVEL_SECONDS := 84.0
const HOOK_SECONDS := 41.0
const EVENT_SECONDS := 41.0
const ITEM_SECONDS := 27.0
const IDLE_SECONDS := 20.0
const CLEAN_GRAND_ENTRY_BANKROLL := 100
const CLEAN_TIER2_ENTRY_BANKROLL := 55
const TIER2_GRAND_ENTRY_BANKROLL := 95
const CHEAT_GRAND_ENTRY_BANKROLL := 80
const DIRECT_GRAND_ENTRY_BANKROLL := 95
const LOW_BANKROLL_LENDER_THRESHOLD := 28
const GRAND_CASINO_ID := "grand_casino"
const TIER2_IDS := ["kitty_cat_lounge", "delta_queen"]

const SCENARIOS := [
	{
		"id": "clean_standard",
		"policy": "clean",
		"challenge_id": "",
		"label": "Clean standard route",
	},
	{
		"id": "clean_pacifist",
		"policy": "clean",
		"challenge_id": "pacifist",
		"label": "Clean pacifist challenge",
	},
	{
		"id": "tier2_standard",
		"policy": "tier2",
		"challenge_id": "",
		"label": "Tier-2 climb route",
	},
	{
		"id": "cheat_standard",
		"policy": "cheat",
		"challenge_id": "",
		"label": "Cheat pressure route",
	},
	{
		"id": "debt_spiral",
		"policy": "debt",
		"challenge_id": "debt_spiral",
		"label": "Debt challenge route",
	},
]

const TARGETS := {
	"overall_victory_rate_min": 0.20,
	"overall_victory_rate_max": 0.75,
	"clean_victory_rate_min": 0.15,
	"cheat_victory_rate_min": 0.20,
	"tier2_usage_rate_min": 0.40,
	"lender_engagement_rate_min": 0.10,
	"challenge_engagement_rate_min": 0.25,
	"debt_terminal_failure_rate_max": 0.50,
	"median_minutes_min": 20.0,
	"median_minutes_max": 40.0,
	"showdown_win_rate_min": 0.30,
	"showdown_win_rate_max": 1.00,
	"showdown_min_attempts_for_rate": 3,
}

var library: ContentLibrary
var generator: RunGenerator
var game_modules: Dictionary = {}
var failures: Array = []
var warnings: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var options := _parse_options()
	var seeds_per_scenario := maxi(1, int(options.get("seeds_per_scenario", DEFAULT_SEEDS_PER_SCENARIO)))
	var max_actions := maxi(1, int(options.get("max_actions", MAX_ACTIONS)))
	var scenario_filter := str(options.get("scenario", "")).strip_edges()
	var seed_prefix := str(options.get("seed_prefix", DEFAULT_SEED_PREFIX)).strip_edges()
	if seed_prefix.is_empty():
		seed_prefix = DEFAULT_SEED_PREFIX
	var output_json := str(options.get("output_json", DEFAULT_OUTPUT_JSON))
	var output_markdown := str(options.get("output_markdown", DEFAULT_OUTPUT_MARKDOWN))

	library = ContentLibraryScript.new()
	library.load()
	for error_value in library.validation_errors:
		failures.append("Content validation error: %s" % str(error_value))
	for warning_value in library.validation_warnings:
		warnings.append("Content validation warning: %s" % str(warning_value))
	generator = RunGeneratorScript.new(library)
	_build_game_modules()

	var runs: Array = []
	var run_index := 0
	for scenario_value in SCENARIOS:
		var scenario: Dictionary = scenario_value
		if not scenario_filter.is_empty() and str(scenario.get("id", "")) != scenario_filter:
			continue
		for seed_index in range(seeds_per_scenario):
			var seed := "%s-%s-%03d" % [seed_prefix, str(scenario.get("id", "")), seed_index + 1]
			runs.append(_simulate_run(run_index, scenario, seed, max_actions))
			run_index += 1

	var aggregate := _build_aggregate(runs, seeds_per_scenario, seed_prefix)
	_assert_targets(aggregate)
	var report := {
		"tool": "endgame_metrics_probe",
		"deterministic": true,
		"seed_prefix": seed_prefix,
		"seeds_per_scenario": seeds_per_scenario,
		"run_count": runs.size(),
		"max_actions": max_actions,
		"scenario_filter": scenario_filter,
		"time_model": {
			"game_action_seconds": GAME_ACTION_SECONDS,
			"travel_seconds": TRAVEL_SECONDS,
			"hook_seconds": HOOK_SECONDS,
			"event_seconds": EVENT_SECONDS,
			"item_seconds": ITEM_SECONDS,
			"idle_seconds": IDLE_SECONDS,
		},
		"targets": TARGETS,
		"passed": failures.is_empty(),
		"aggregate": aggregate,
		"runs": runs,
		"failures": failures,
		"warnings": warnings,
	}
	_write_json(output_json, report)
	_write_markdown(output_markdown, report)
	_print_summary(output_json, output_markdown, aggregate)
	await _finish(0 if failures.is_empty() else 1)


func _finish(exit_code: int) -> void:
	await process_frame
	quit(exit_code)


func _parse_options() -> Dictionary:
	var options := {}
	for arg_value in OS.get_cmdline_user_args():
		var arg := str(arg_value)
		if arg.begins_with("--seeds-per-scenario="):
			options["seeds_per_scenario"] = maxi(1, int(arg.trim_prefix("--seeds-per-scenario=")))
		elif arg.begins_with("--seed-prefix="):
			options["seed_prefix"] = arg.trim_prefix("--seed-prefix=")
		elif arg.begins_with("--scenario="):
			options["scenario"] = arg.trim_prefix("--scenario=")
		elif arg.begins_with("--max-actions="):
			options["max_actions"] = maxi(1, int(arg.trim_prefix("--max-actions=")))
		elif arg.begins_with("--output="):
			options["output_json"] = arg.trim_prefix("--output=")
		elif arg.begins_with("--report="):
			options["output_markdown"] = arg.trim_prefix("--report=")
	return options


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


func _create_game_module(definition: Dictionary) -> GameModule:
	var module_path := str(definition.get("module_path", "")).strip_edges()
	if module_path.is_empty() or module_path.ends_with("_ui.gd") or module_path.begins_with("res://data/runtime/"):
		return null
	var module_script: Script = load(module_path)
	if module_script == null:
		return null
	var module_instance: Object = module_script.new()
	if not module_instance is GameModule:
		return null
	var game: GameModule = module_instance
	game.setup(definition, library)
	return game


func _simulate_run(run_index: int, scenario: Dictionary, seed: String, max_actions: int = MAX_ACTIONS) -> Dictionary:
	var policy := str(scenario.get("policy", "clean"))
	var challenge_id := str(scenario.get("challenge_id", "")).strip_edges()
	var challenge_config := RunStateScript.standard_challenge(seed)
	if not challenge_id.is_empty():
		challenge_config = library.challenge_config_for(challenge_id, seed)
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed, challenge_config)
	generator.next_environment(run_state)

	var run := {
		"run_index": run_index,
		"seed": seed,
		"scenario_id": str(scenario.get("id", "")),
		"scenario_label": str(scenario.get("label", "")),
		"policy": policy,
		"challenge_id": challenge_id,
		"challenge_engaged": not challenge_id.is_empty(),
		"start_bankroll": run_state.bankroll,
		"actions": 0,
		"game_actions": 0,
		"legal_actions": 0,
		"cheat_actions": 0,
		"travel_count": 0,
		"tier2_visits": 0,
		"lender_uses": 0,
		"service_uses": 0,
		"item_purchases": 0,
		"events_resolved": 0,
		"showdown_attempted": false,
		"showdown_won": false,
		"showdown_success_chance": 0,
		"grand_casino_entries": 0,
		"route_cost_total": 0,
		"service_use_keys": {},
		"stopped_reason": "action_cap",
		"curve": [],
		"travel_decisions": [],
		"visited_archetypes": [],
		"game_mix": {},
		"failure_reason": "",
		"victory_route": "",
	}
	_record_curve(run, run_state, "start")
	_record_visit(run, run_state)

	for action_index in range(max_actions):
		if run_state.is_terminal():
			run["stopped_reason"] = "terminal"
			break
		if _try_claim_or_resolve_endgame(run_state, run):
			_count_action(run, "event")
			_record_curve(run, run_state, "endgame")
			continue
		if _try_buy_helpful_item(run_state, run, policy):
			_count_action(run, "item")
			_record_curve(run, run_state, "item")
			continue
		if _try_use_pressure_service(run_state, run, policy):
			_count_action(run, "hook")
			_record_curve(run, run_state, "service")
			continue
		if _try_use_lender(run_state, run, policy):
			_count_action(run, "hook")
			_record_curve(run, run_state, "lender")
			continue
		if _should_travel_now(run_state, run, policy):
			var traveled := _try_travel(run_state, run, policy)
			if traveled:
				_count_action(run, "travel")
				_record_visit(run, run_state)
				_record_curve(run, run_state, "travel")
				continue
		if _try_play_game(run_state, run, policy):
			_count_action(run, "game")
			_record_curve(run, run_state, "game")
			continue
		if _try_resolve_event(run_state, run, policy):
			_count_action(run, "event")
			_record_curve(run, run_state, "event")
			continue
		if _try_travel(run_state, run, policy):
			_count_action(run, "travel")
			_record_visit(run, run_state)
			_record_curve(run, run_state, "travel")
			continue
		if run_state.bankroll <= 0:
			run_state.fail_run(RunState.FAILURE_BANKROLL_ZERO, RunState.BANKROLL_ZERO_FAILURE_MESSAGE)
			run["stopped_reason"] = "bankroll_zero"
			break
		run_state.advance_environment_turns(1)
		_count_action(run, "idle")
		_record_curve(run, run_state, "idle")

	_finalize_run(run, run_state)
	return run


func _try_claim_or_resolve_endgame(run_state: RunState, run: Dictionary) -> bool:
	var status := run_state.demo_objective_status()
	if not bool(status.get("grand_casino_objective", false)):
		return false
	run_state.evaluate_environment_objective_state()
	status = run_state.demo_objective_status()
	if bool(status.get("high_roller_ready", false)) or bool(status.get("high_roller_cashout_pending", false)):
		var cashout: Dictionary = run_state.complete_grand_casino_high_roller_cashout()
		return bool(cashout.get("ok", false))
	if bool(status.get("showdown_ready", false)) or bool(status.get("showdown_pending", false)) or bool(status.get("showdown_active", false)):
		run_state.evaluate_environment_objective_state()
		var choice := "talk_down"
		var policy := str(run.get("policy", "clean"))
		if policy == "cheat" or policy == "debt":
			choice = "take_the_edge"
		elif policy == "clean":
			choice = "hold_steady"
		var started: Dictionary = run_state.start_grand_casino_showdown()
		if not bool(started.get("ok", false)) and not bool(run_state.narrative_flags.get("grand_casino_showdown_active", false)):
			return false
		run_state.narrative_flags["grand_casino_showdown_roll"] = _metrics_showdown_roll(run)
		var resolved: Dictionary = run_state.resolve_grand_casino_showdown_pressure(choice)
		run["showdown_attempted"] = true
		run["showdown_won"] = bool(resolved.get("success", false))
		var check: Dictionary = _dict(resolved.get("check", {}))
		run["showdown_success_chance"] = int(check.get("success_chance", 0))
		return bool(resolved.get("ok", false))
	return false


func _try_buy_helpful_item(run_state: RunState, run: Dictionary, policy: String) -> bool:
	if run_state.current_environment.is_empty() or run_state.bankroll < 8:
		return false
	var service: RunActionService = RunActionServiceScript.new()
	service.setup(library, run_state)
	var offers := service.item_offer_view_list()
	var best_offer := {}
	var best_score := -999
	for offer_value in offers:
		if typeof(offer_value) != TYPE_DICTIONARY:
			continue
		var offer: Dictionary = offer_value
		if not bool(offer.get("affordable", false)):
			continue
		var item_id := str(offer.get("id", ""))
		if run_state.inventory.has(item_id):
			continue
		var price := maxi(0, int(offer.get("price", 0)))
		if price > _max_item_budget(run_state, policy):
			continue
		var score := _item_score(item_id, policy) - price
		if score > best_score:
			best_score = score
			best_offer = offer
	if best_offer.is_empty() or best_score < 0:
		return false
	var result: Dictionary = service.buy_item_offer(str(best_offer.get("id", "")))
	if not bool(result.get("ok", false)):
		return false
	run["item_purchases"] = int(run.get("item_purchases", 0)) + 1
	return true


func _try_use_pressure_service(run_state: RunState, run: Dictionary, policy: String) -> bool:
	var service: RunActionService = RunActionServiceScript.new()
	service.setup(library, run_state)
	var options := service.service_hook_view_list()
	var best_option := {}
	var best_score := -999
	for option_value in options:
		if typeof(option_value) != TYPE_DICTIONARY:
			continue
		var option: Dictionary = option_value
		if not bool(option.get("enabled", false)) or not bool(option.get("mutation_supported", false)):
			continue
		var service_id := str(option.get("id", ""))
		var service_key := "%s:%s" % [str(run_state.current_environment.get("id", "")), service_id]
		var used_services: Dictionary = _dict(run.get("service_use_keys", {}))
		if bool(used_services.get(service_key, false)):
			continue
		var cost := maxi(0, int(option.get("cost", 0)))
		if cost > run_state.bankroll or cost > _max_service_budget(run_state, policy):
			continue
		var score := _service_score(service_id, policy, run_state.suspicion_level(), run_state) - cost
		if score > best_score:
			best_score = score
			best_option = option
	if best_option.is_empty() or best_score < 3:
		return false
	var used: Dictionary = service.use_hook("service", str(best_option.get("id", "")))
	if not bool(used.get("ok", false)):
		return false
	var selected_id := str(best_option.get("id", ""))
	var selected_key := "%s:%s" % [str(run_state.current_environment.get("id", "")), selected_id]
	var service_use_keys: Dictionary = _dict(run.get("service_use_keys", {}))
	service_use_keys[selected_key] = true
	run["service_use_keys"] = service_use_keys
	run["service_uses"] = int(run.get("service_uses", 0)) + 1
	return true


func _try_use_lender(run_state: RunState, run: Dictionary, policy: String) -> bool:
	if run_state.bankroll > _lender_threshold(policy) and int(run.get("lender_uses", 0)) > 0:
		return false
	if run_state.bankroll > _lender_threshold(policy) and policy != "debt":
		return false
	var service: RunActionService = RunActionServiceScript.new()
	service.setup(library, run_state)
	var options := service.lender_hook_view_list()
	var best_option := {}
	var best_score := -999
	for option_value in options:
		if typeof(option_value) != TYPE_DICTIONARY:
			continue
		var option: Dictionary = option_value
		if not bool(option.get("enabled", false)) or not bool(option.get("mutation_supported", false)):
			continue
		var lender_id := str(option.get("id", ""))
		if _run_has_lender_debt(run_state, lender_id):
			continue
		var score := _lender_score(lender_id, policy, run_state.bankroll)
		if score > best_score:
			best_score = score
			best_option = option
	if best_option.is_empty() or best_score < 0:
		return false
	var used: Dictionary = service.use_hook("lender", str(best_option.get("id", "")))
	if not bool(used.get("ok", false)):
		return false
	run["lender_uses"] = int(run.get("lender_uses", 0)) + 1
	return true


func _try_resolve_event(run_state: RunState, run: Dictionary, policy: String) -> bool:
	var event_ids := _current_event_ids(run_state)
	var best_event_id := ""
	var best_choice_id := ""
	var best_score := -999
	for event_id_value in event_ids:
		var event_id := str(event_id_value)
		var definition := library.event(event_id)
		if definition.is_empty():
			continue
		var event := EventModuleScript.new()
		event.setup(definition, library)
		if not event.can_trigger(run_state, run_state.current_environment):
			continue
		for choice_value in event.choices(run_state, run_state.current_environment):
			if typeof(choice_value) != TYPE_DICTIONARY:
				continue
			var choice: Dictionary = choice_value
			var choice_id := str(choice.get("id", ""))
			var score := _event_choice_score(choice, policy, run_state)
			if score > best_score:
				best_score = score
				best_event_id = event_id
				best_choice_id = choice_id
	if best_event_id.is_empty() or best_score < 0:
		return false
	var selected_definition := library.event(best_event_id)
	var selected_event := EventModuleScript.new()
	selected_event.setup(selected_definition, library)
	var result: Dictionary = selected_event.resolve(run_state, run_state.current_environment, best_choice_id)
	if not bool(result.get("ok", false)):
		return false
	run_state.advance_environment_turns(1)
	run["events_resolved"] = int(run.get("events_resolved", 0)) + 1
	return true


func _should_travel_now(run_state: RunState, run: Dictionary, policy: String) -> bool:
	if run_state.current_environment.is_empty():
		return true
	var archetype_id := str(run_state.current_environment.get("archetype_id", ""))
	if archetype_id == GRAND_CASINO_ID:
		return false
	if run_state.bankroll >= _grand_entry_target(policy, int(run.get("tier2_visits", 0))) and _travel_target_available(run_state, GRAND_CASINO_ID):
		return true
	if _policy_allows_cheat(policy) and run_state.suspicion_level() >= 35 and _has_affordable_non_looping_travel(run_state, run):
		return true
	if policy == "tier2" and int(run.get("tier2_visits", 0)) <= 0 and _tier2_target_available(run_state):
		return _can_afford_any_target(run_state, TIER2_IDS)
	if policy == "clean" and int(run.get("tier2_visits", 0)) <= 0 and _tier2_target_available(run_state):
		return run_state.bankroll >= CLEAN_TIER2_ENTRY_BANKROLL and _can_afford_any_target(run_state, TIER2_IDS)
	if not _string_array(run_state.current_environment.get("game_ids", [])).is_empty() and run_state.bankroll >= _current_stake_floor(run_state):
		if int(run_state.current_environment.get("turns", 0)) < _max_turns_before_travel(policy, archetype_id):
			return false
		var affordable_non_looping := _has_affordable_non_looping_travel(run_state, run)
		if not affordable_non_looping and run_state.bankroll < 80:
			return false
	if int(run_state.current_environment.get("turns", 0)) >= _max_turns_before_travel(policy, archetype_id):
		return true
	return false


func _try_travel(run_state: RunState, run: Dictionary, policy: String) -> bool:
	var choices := _travel_choices(run_state)
	var best_choice := {}
	var best_score := -99999
	var scored_choices: Array = []
	for choice_value in choices:
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = choice_value
		if not bool(choice.get("enabled", false)):
			continue
		var cost := maxi(0, int(choice.get("cost", 0)))
		if cost > run_state.bankroll:
			continue
		if run_state.bankroll - cost < _destination_minimum_bankroll(str(choice.get("id", ""))):
			continue
		var score := _travel_score(run_state, run, choice, policy)
		scored_choices.append({
			"id": str(choice.get("id", "")),
			"enabled": bool(choice.get("enabled", false)),
			"cost": cost,
			"tier": int(choice.get("tier", 1)),
			"kind": str(choice.get("kind", "")),
			"score": score,
		})
		if score > best_score:
			best_score = score
			best_choice = choice
	if best_choice.is_empty():
		_record_travel_decision(run, run_state, scored_choices, "", best_score, "no_choice")
		var lock_remaining := run_state.current_travel_lock_remaining()
		if lock_remaining > 0:
			run_state.advance_environment_turns(lock_remaining)
			return _try_travel(run_state, run, policy)
		return false
	if best_score < -500 and not _string_array(run_state.current_environment.get("game_ids", [])).is_empty():
		_record_travel_decision(run, run_state, scored_choices, str(best_choice.get("id", "")), best_score, "deferred")
		return false
	_record_travel_decision(run, run_state, scored_choices, str(best_choice.get("id", "")), best_score, "travel")
	return _apply_travel_choice(run_state, run, best_choice)


func _try_play_game(run_state: RunState, run: Dictionary, policy: String) -> bool:
	var game_id := _pick_game_id(run_state, policy)
	if game_id.is_empty():
		return false
	var game: GameModule = game_modules.get(game_id, null)
	if game == null:
		return false
	var action_id := _pick_game_action_id(game, run_state, run_state.current_environment, policy)
	if action_id.is_empty():
		return false
	var stake := _stake_for_game(run_state, game, action_id, policy)
	if stake <= 0:
		return false
	var rng := run_state.create_rng()
	var result: Dictionary = game.resolve_with_context(action_id, stake, run_state, run_state.current_environment, rng, _ui_state_for_game(game_id, action_id, stake, policy))
	if not bool(result.get("ok", false)):
		return false
	if bool(result.get("host_apply_result", false)):
		GameModule.apply_result(run_state, result, rng)
	else:
		run_state.save_rng(rng)
	if not bool(result.get("slot_runtime_tick", false)):
		run_state.advance_environment_turns(1)
	run["game_actions"] = int(run.get("game_actions", 0)) + 1
	var action_kind := str(result.get("action_kind", ""))
	if action_kind == "cheat" or action_kind == "risky" or action_kind == "advantage":
		run["cheat_actions"] = int(run.get("cheat_actions", 0)) + 1
	else:
		run["legal_actions"] = int(run.get("legal_actions", 0)) + 1
	var mix: Dictionary = _dict(run.get("game_mix", {}))
	mix[game_id] = int(mix.get(game_id, 0)) + 1
	run["game_mix"] = mix
	return true


func _apply_travel_choice(run_state: RunState, run: Dictionary, choice: Dictionary) -> bool:
	var target_id := str(choice.get("id", "")).strip_edges()
	var route: Dictionary = _dict(choice.get("route", {}))
	if target_id.is_empty() or route.is_empty():
		return false
	var previous_environment := run_state.current_environment.duplicate(true)
	var route_risk := run_state.travel_route_risk(route, target_id)
	var travel_heat := run_state.begin_travel_suspicion_decay(route, target_id)
	generator.next_environment(run_state, target_id)
	var travel_decay := run_state.finish_travel_suspicion_decay(travel_heat)
	var result := _travel_result(target_id, previous_environment, run_state.current_environment, route, travel_decay, route_risk)
	GameModule.apply_result(run_state, result)
	run["travel_count"] = int(run.get("travel_count", 0)) + 1
	run["route_cost_total"] = int(run.get("route_cost_total", 0)) + maxi(0, int(result.get("route_cost", 0)))
	if target_id == GRAND_CASINO_ID:
		run["grand_casino_entries"] = int(run.get("grand_casino_entries", 0)) + 1
	return true


func _travel_result(target_id: String, previous_environment: Dictionary, destination_environment: Dictionary, route: Dictionary, travel_decay: Dictionary, route_risk: Dictionary) -> Dictionary:
	var route_status := _current_run_route_status(route)
	var cost := int(route_status.get("cost", route.get("cost", 0)))
	var suspicion_delta := int(route_status.get("suspicion_delta", route.get("suspicion_delta", 0)))
	var risk_bankroll_delta := int(route_risk.get("bankroll_delta", 0)) if bool(route_risk.get("triggered", false)) else 0
	var risk_suspicion_delta := int(route_risk.get("suspicion_delta", 0)) if bool(route_risk.get("triggered", false)) else 0
	var total_bankroll_delta := -cost + risk_bankroll_delta
	var total_suspicion_delta := suspicion_delta + risk_suspicion_delta
	var destination_name := str(destination_environment.get("display_name", target_id.replace("_", " ").capitalize()))
	var message := "Metrics travel to %s." % destination_name
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
		"risk_decay": int(travel_decay.get("risk_decay", route_status.get("risk_decay", 0))),
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


func _current_run_route_status(route: Dictionary) -> Dictionary:
	# This helper is patched by _apply_travel_choice through the route status values
	# already stored on the choice; it exists to keep the travel-result shape small.
	return route.duplicate(true)


func _travel_choices(run_state: RunState) -> Array:
	var result: Array = []
	var target_ids: Array = []
	if run_state.has_world_map():
		var source_id := run_state.current_world_node_id()
		target_ids = WorldMapScript.travel_target_ids(run_state.world_map, source_id, WorldMapScript.TRAVEL_NEW_TARGET_LIMIT, WorldMapScript.TRAVEL_TOTAL_TARGET_LIMIT, _enabled_world_route_ids(run_state, source_id))
	else:
		target_ids = _unique_strings(_string_array(run_state.current_environment.get("next_archetypes", [])) + _string_array(run_state.current_environment.get("travel_hooks", [])))
	for target_value in target_ids:
		var target_id := str(target_value)
		var route := generator.world_route_for_target(run_state, target_id)
		if route.is_empty():
			route = library.route(target_id)
		if route.is_empty():
			continue
		var status := run_state.travel_route_status(route)
		result.append({
			"id": target_id,
			"route": route,
			"cost": int(status.get("cost", route.get("cost", 0))),
			"enabled": bool(status.get("available", true)) and not bool(status.get("hidden", false)),
			"hidden": bool(status.get("hidden", false)),
			"disabled_reason": str(status.get("disabled_reason", "")),
			"status": status,
			"tier": _archetype_tier(target_id),
			"kind": _archetype_kind(target_id),
		})
	return result


func _enabled_world_route_ids(run_state: RunState, source_id: String) -> Array:
	var result: Array = []
	for target_id_value in WorldMapScript.visible_node_ids(run_state.world_map):
		var target_id := str(target_id_value)
		if target_id == source_id or not WorldMapScript.has_path(run_state.world_map, source_id, target_id, true):
			continue
		var route := generator.world_route_for_target(run_state, target_id)
		if route.is_empty():
			continue
		var status := run_state.travel_route_status(route)
		if not bool(status.get("hidden", false)) and bool(status.get("available", true)):
			result.append(target_id)
	return result


func _pick_game_id(run_state: RunState, policy: String) -> String:
	var game_ids := _string_array(run_state.current_environment.get("game_ids", []))
	var best_id := ""
	var best_score := -999
	for game_id_value in game_ids:
		var game_id := str(game_id_value)
		if not game_modules.has(game_id):
			continue
		var score := _game_preference_score(game_id, policy, run_state)
		if score > best_score:
			best_score = score
			best_id = game_id
	return best_id


func _pick_game_action_id(game: GameModule, run_state: RunState, environment: Dictionary, policy: String) -> String:
	if _policy_allows_cheat(policy) and run_state.suspicion_level() < _cheat_heat_ceiling(policy):
		var cheat_actions := game.cheat_actions(run_state, environment)
		var preferred_cheat := _preferred_cheat_action(game.get_id(), cheat_actions)
		if not preferred_cheat.is_empty():
			return preferred_cheat
	var legal_actions := game.legal_actions(run_state, environment)
	if legal_actions.is_empty():
		return ""
	var legal_action: Dictionary = legal_actions[0]
	return str(legal_action.get("id", ""))


func _stake_for_game(run_state: RunState, game: GameModule, action_id: String, policy: String) -> int:
	var profile: Dictionary = _dict(run_state.current_environment.get("economic_profile", {}))
	var floor := maxi(1, int(profile.get("stake_floor", 1)))
	var ceiling := run_state.wager_stake_ceiling(int(profile.get("stake_ceiling", run_state.bankroll)))
	var available := mini(ceiling, maxi(0, run_state.bankroll))
	if available < floor:
		return 0
	var target := floor
	var archetype_id := str(run_state.current_environment.get("archetype_id", ""))
	if archetype_id == GRAND_CASINO_ID:
		if policy == "cheat":
			target = mini(available, maxi(floor, int(floor(float(run_state.bankroll) / 3.0))))
		elif policy == "debt":
			target = mini(available, maxi(floor, int(floor(float(run_state.bankroll) / 4.0))))
		else:
			target = mini(available, maxi(floor, int(floor(float(run_state.bankroll) / 6.0))))
	elif policy == "cheat":
		target = mini(available, maxi(floor, int(floor(float(run_state.bankroll) / 4.0))))
	elif policy == "tier2":
		target = mini(available, maxi(floor, int(floor(float(run_state.bankroll) / 5.0))))
	else:
		target = mini(available, maxi(floor, int(floor(float(run_state.bankroll) / 6.0))))
	var cost := game.wager_cost_for_context(action_id, target, run_state, run_state.current_environment, _ui_state_for_game(game.get_id(), action_id, target, policy))
	if cost <= 0 and action_id == "spin_roulette":
		cost = target
	if cost > run_state.bankroll:
		target = floor
	return clampi(target, floor, available)


func _ui_state_for_game(game_id: String, action_id: String, stake: int, policy: String) -> Dictionary:
	var ui_state: Dictionary = {
		"surface_time_msec": _metrics_surface_time_msec(game_id, action_id, stake, policy),
	}
	match game_id:
		"roulette":
			ui_state["roulette_bets"] = [_roulette_bet(stake, policy)]
			return ui_state
		"baccarat":
			ui_state["baccarat_bets"] = _baccarat_bets(stake, policy)
			return ui_state
		"video_poker":
			ui_state["bet_level"] = 1
			return ui_state
		"pull_tabs":
			ui_state["pull_tab_deal_index"] = 0
			return ui_state
		"slot":
			if action_id == "nudge":
				ui_state["slot_nudge_chain_input_msec"] = 0
			return ui_state
		_:
			return ui_state


func _metrics_surface_time_msec(game_id: String, action_id: String, stake: int, policy: String) -> int:
	var seed := "%s:%s:%d:%s:surface_time" % [game_id, action_id, stake, policy]
	return 12000 + int(_stable_hash(seed) % 48000)


func _roulette_bet(stake: int, policy: String) -> Dictionary:
	if policy == "cheat":
		return {"id": "straight_17", "family": "inside", "target": "17", "amount": stake, "payout": 35}
	return {"id": "red", "family": "outside", "target": "red", "amount": stake, "payout": 1}


func _baccarat_bets(stake: int, policy: String) -> Dictionary:
	if policy == "cheat":
		return {"banker": stake}
	return {"player": stake}


func _travel_score(run_state: RunState, run: Dictionary, choice: Dictionary, policy: String) -> int:
	var target_id := str(choice.get("id", ""))
	var tier := int(choice.get("tier", 1))
	var kind := str(choice.get("kind", ""))
	var cost := int(choice.get("cost", 0))
	var visited := _array(run.get("visited_archetypes", []))
	var score := 0
	if target_id == GRAND_CASINO_ID:
		score += 10000 if run_state.bankroll >= _grand_entry_target(policy, int(run.get("tier2_visits", 0))) else -5000
	if TIER2_IDS.has(target_id):
		score += 2500 if policy == "tier2" else 1000
		if int(run.get("tier2_visits", 0)) > 0:
			score -= 1200
	if kind == "casino":
		score += 600
	if kind == "shop":
		score += 280 if run_state.bankroll < 80 else 80
	if policy == "cheat" and target_id == "small_underground_casino":
		score += 1200
	if not visited.has(target_id):
		score += 500
	elif visited.size() >= 2 and str(visited[visited.size() - 2]) == target_id:
		score -= 1400
	score += tier * 120
	score -= cost * 18
	if run_state.bankroll - cost < _destination_minimum_bankroll(target_id):
		score -= 2000
	return score


func _game_preference_score(game_id: String, policy: String, run_state: RunState) -> int:
	var score_by_game := {
		"bar_dice": 80,
		"blackjack": 74,
		"video_poker": 72,
		"roulette": 62,
		"baccarat": 60,
		"slot": 50,
		"pull_tabs": 40,
	}
	var score := int(score_by_game.get(game_id, 30))
	if policy == "cheat":
		var cheat_bonus := {
			"bar_dice": 35,
			"video_poker": 30,
			"roulette": 18,
			"baccarat": 14,
			"blackjack": 12,
			"pull_tabs": 8,
			"slot": 4,
		}
		score += int(cheat_bonus.get(game_id, 0))
	if str(run_state.current_environment.get("archetype_id", "")) == GRAND_CASINO_ID:
		if policy == "cheat":
			score += 20 if ["bar_dice", "roulette", "baccarat"].has(game_id) else 0
		else:
			var clean_grand_bonus := {
				"blackjack": 38,
				"baccarat": 32,
				"video_poker": 28,
				"roulette": 12,
				"bar_dice": -10,
			}
			score += int(clean_grand_bonus.get(game_id, 0))
	return score


func _preferred_cheat_action(game_id: String, cheat_actions: Array) -> String:
	var preferred := {
		"bar_dice": ["palmed_swap", "loaded_toss"],
		"video_poker": ["mark_holds"],
		"roulette": ["past_post", "read_wheel_bias"],
		"baccarat": ["edge_sort", "read_baccarat_shoe"],
		"blackjack": ["peek_hole_card", "count_cards"],
		"pull_tabs": ["tab_detector_scan"],
		"slot": ["nudge"],
	}
	var ids := _action_ids(cheat_actions)
	for candidate_value in _array(preferred.get(game_id, [])):
		var candidate := str(candidate_value)
		if ids.has(candidate):
			return candidate
	return ""


func _event_choice_score(choice: Dictionary, policy: String, run_state: RunState) -> int:
	var consequences: Dictionary = _dict(choice.get("consequences", {}))
	var score := int(consequences.get("bankroll_delta", 0)) * 4
	score -= maxi(0, int(consequences.get("suspicion_delta", 0))) * (5 if policy == "clean" else 2)
	score += maxi(0, -int(consequences.get("suspicion_delta", 0))) * 7
	score += int(consequences.get("baseline_luck_delta", 0)) * 20
	score += _string_array(consequences.get("add_next_archetypes", [])).size() * 80
	score += _string_array(consequences.get("set_next_archetypes", [])).size() * 60
	if str(choice.get("id", "")).find("decline") >= 0 and run_state.suspicion_level() <= 25:
		score += 8
	return score


func _item_score(item_id: String, policy: String) -> int:
	var item := library.item(item_id)
	var effect: Dictionary = _dict(item.get("effect", {}))
	var score := 0
	score += int(effect.get("win_chance", effect.get("legal_win_chance", 0))) * 12
	score += int(effect.get("win_bonus", 0)) * 10
	score += int(effect.get("loss_reduction", 0)) * 8
	score += int(effect.get("baseline_luck_delta", 0)) * 20
	score += int(effect.get("travel_scouting_level", 0)) * 28
	score += int(effect.get("debt_grace_turns", 0)) * (22 if policy == "debt" else 10)
	score -= maxi(0, int(effect.get("cheat_suspicion_delta", 0))) * (8 if policy == "clean" else 1)
	if str(item.get("class", "")) == "contraband" and policy == "clean":
		score -= 90
	if item_id in ["cheap_sunglasses", "card_counters_notes", "scratch_pad", "creased_luck_card", "lucky_keychain"]:
		score += 32
	return score


func _service_score(service_id: String, policy: String, heat: int, run_state: RunState) -> int:
	var service := library.service(service_id)
	var effect: Dictionary = _dict(service.get("effect", {}))
	var category := str(service.get("category", ""))
	if int(effect.get("alcohol_intake", 0)) > 0:
		return -10000
	var score := 0
	score += maxi(0, -int(effect.get("suspicion_delta", 0))) * (8 if policy == "clean" else 4)
	score += int(effect.get("baseline_luck_delta", 0)) * 20
	score += int(effect.get("drunk_delta", 0)) * 2
	score -= maxi(0, int(effect.get("suspicion_delta", 0))) * 5
	if service_id == "cashier_tip" and bool(run_state.narrative_flags.get("route_scouting_active", false)):
		score -= 40
	if service_id == "cashier_tip" and heat < 18:
		score -= 12
	if heat >= 35:
		score += 25
	if (service_id.find("drink") >= 0 or category == "alcohol") and policy == "clean":
		score -= 12
	return score


func _lender_score(lender_id: String, policy: String, bankroll: int) -> int:
	var score := 10
	if policy == "debt":
		score += 40
	if lender_id == "motel_friend" or lender_id == "brother_in_law":
		score += 20
	if lender_id == "street_lender":
		score += 12 if bankroll < 20 else -5
	if lender_id == "the_crew":
		score += 8
	if lender_id == "sals_pawn_counter":
		score += 4
	score += maxi(0, LOW_BANKROLL_LENDER_THRESHOLD - bankroll)
	return score


func _max_item_budget(run_state: RunState, policy: String) -> int:
	if policy == "cheat":
		return maxi(12, int(floor(float(run_state.bankroll) * 0.25)))
	if policy == "debt":
		return maxi(10, int(floor(float(run_state.bankroll) * 0.20)))
	return maxi(8, int(floor(float(run_state.bankroll) * 0.18)))


func _max_service_budget(run_state: RunState, policy: String) -> int:
	if policy == "clean":
		return maxi(5, int(floor(float(run_state.bankroll) * 0.12)))
	return maxi(6, int(floor(float(run_state.bankroll) * 0.16)))


func _lender_threshold(policy: String) -> int:
	if policy == "debt":
		return 55
	if policy == "cheat":
		return 34
	return LOW_BANKROLL_LENDER_THRESHOLD


func _grand_entry_target(policy: String, tier2_visits: int) -> int:
	if policy == "cheat":
		return CHEAT_GRAND_ENTRY_BANKROLL
	if policy == "tier2":
		return TIER2_GRAND_ENTRY_BANKROLL if tier2_visits > 0 else CLEAN_GRAND_ENTRY_BANKROLL
	if policy == "debt":
		return DIRECT_GRAND_ENTRY_BANKROLL
	return CLEAN_GRAND_ENTRY_BANKROLL


func _max_turns_before_travel(policy: String, archetype_id: String) -> int:
	if archetype_id == GRAND_CASINO_ID:
		return MAX_ACTIONS
	if policy == "cheat":
		return 2
	if policy == "debt":
		return 4
	if policy == "tier2":
		return 7
	return 8


func _cheat_heat_ceiling(policy: String) -> int:
	if policy == "cheat":
		return 82
	if policy == "debt":
		return 68
	return 0


func _policy_allows_cheat(policy: String) -> bool:
	return policy == "cheat" or policy == "debt"


func _travel_target_available(run_state: RunState, target_id: String) -> bool:
	for choice_value in _travel_choices(run_state):
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = choice_value
		if str(choice.get("id", "")) == target_id and bool(choice.get("enabled", false)):
			return true
	return false


func _can_afford_any_target(run_state: RunState, target_ids: Array) -> bool:
	for choice_value in _travel_choices(run_state):
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = choice_value
		var target_id := str(choice.get("id", ""))
		if not target_ids.has(target_id) or not bool(choice.get("enabled", false)):
			continue
		var cost := maxi(0, int(choice.get("cost", 0)))
		if run_state.bankroll - cost >= _destination_minimum_bankroll(target_id):
			return true
	return false


func _tier2_target_available(run_state: RunState) -> bool:
	for target_id in TIER2_IDS:
		if _travel_target_available(run_state, str(target_id)):
			return true
	return false


func _current_stake_floor(run_state: RunState) -> int:
	var profile: Dictionary = _dict(run_state.current_environment.get("economic_profile", {}))
	return maxi(1, int(profile.get("stake_floor", 1)))


func _destination_minimum_bankroll(archetype_id: String) -> int:
	var archetype := _archetype(archetype_id)
	var profile: Dictionary = _dict(archetype.get("economic_profile", {}))
	var floor := maxi(1, int(profile.get("stake_floor", 1)))
	var kind := str(archetype.get("kind", ""))
	if kind == "shop":
		return 3
	if archetype_id == GRAND_CASINO_ID:
		return floor * 2
	return floor * 2


func _has_affordable_non_looping_travel(run_state: RunState, run: Dictionary) -> bool:
	var visited := _array(run.get("visited_archetypes", []))
	for choice_value in _travel_choices(run_state):
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = choice_value
		if not bool(choice.get("enabled", false)):
			continue
		var target_id := str(choice.get("id", ""))
		var cost := maxi(0, int(choice.get("cost", 0)))
		if run_state.bankroll - cost < _destination_minimum_bankroll(target_id):
			continue
		if visited.size() >= 2 and str(visited[visited.size() - 2]) == target_id:
			continue
		return true
	return false


func _run_has_lender_debt(run_state: RunState, lender_id: String) -> bool:
	for debt_value in run_state.debt:
		if typeof(debt_value) != TYPE_DICTIONARY:
			continue
		var debt_data: Dictionary = debt_value
		if str(debt_data.get("lender_id", "")) == lender_id and str(debt_data.get("status", "active")) != "paid":
			return true
	return false


func _current_event_ids(run_state: RunState) -> Array:
	var result: Array = []
	for pending_value in run_state.pending_triggered_events:
		if typeof(pending_value) != TYPE_DICTIONARY:
			continue
		var pending: Dictionary = pending_value
		var event_id := str(pending.get("event_id", pending.get("id", "")))
		if not event_id.is_empty() and not result.has(event_id):
			result.append(event_id)
	for event_id in _string_array(run_state.current_environment.get("event_ids", [])):
		if not result.has(event_id):
			result.append(event_id)
	return result


func _record_visit(run: Dictionary, run_state: RunState) -> void:
	var archetype_id := str(run_state.current_environment.get("archetype_id", ""))
	var visited: Array = _array(run.get("visited_archetypes", []))
	if not archetype_id.is_empty():
		visited.append(archetype_id)
		run["visited_archetypes"] = visited
	if TIER2_IDS.has(archetype_id):
		run["tier2_visits"] = int(run.get("tier2_visits", 0)) + 1


func _record_curve(run: Dictionary, run_state: RunState, label: String) -> void:
	var curve: Array = _array(run.get("curve", []))
	curve.append({
		"step": curve.size(),
		"label": label,
		"bankroll": run_state.bankroll,
		"heat": run_state.suspicion_level(),
		"debt_balance": _total_debt_balance(run_state),
		"environment": str(run_state.current_environment.get("archetype_id", "")),
	})
	run["curve"] = curve


func _record_travel_decision(run: Dictionary, run_state: RunState, choices: Array, selected_id: String, score: int, outcome: String) -> void:
	var decisions: Array = _array(run.get("travel_decisions", []))
	if decisions.size() >= 24:
		return
	decisions.append({
		"step": int(run.get("actions", 0)),
		"environment": str(run_state.current_environment.get("archetype_id", "")),
		"world_node": run_state.current_world_node_id(),
		"visible_nodes": WorldMapScript.visible_node_ids(run_state.world_map) if run_state.has_world_map() else [],
		"node_states": _world_node_states(run_state),
		"neighbors": WorldMapScript.neighbor_ids(run_state.world_map, run_state.current_world_node_id(), false) if run_state.has_world_map() else [],
		"visible_neighbors": WorldMapScript.neighbor_ids(run_state.world_map, run_state.current_world_node_id(), true) if run_state.has_world_map() else [],
		"bankroll": run_state.bankroll,
		"selected": selected_id,
		"score": score,
		"outcome": outcome,
		"choices": choices.duplicate(true),
	})
	run["travel_decisions"] = decisions


func _world_node_states(run_state: RunState) -> Dictionary:
	var result: Dictionary = {}
	if not run_state.has_world_map():
		return result
	for node_value in _array(run_state.world_map.get("nodes", [])):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := str(node.get("id", ""))
		if node_id.is_empty():
			continue
		result[node_id] = str(node.get("state", ""))
	return result


func _count_action(run: Dictionary, action_type: String) -> void:
	run["actions"] = int(run.get("actions", 0)) + 1
	var seconds := float(run.get("estimated_seconds", 0.0))
	match action_type:
		"game":
			seconds += GAME_ACTION_SECONDS
		"travel":
			seconds += TRAVEL_SECONDS
		"hook":
			seconds += HOOK_SECONDS
		"event":
			seconds += EVENT_SECONDS
		"item":
			seconds += ITEM_SECONDS
		_:
			seconds += IDLE_SECONDS
	run["estimated_seconds"] = seconds


func _finalize_run(run: Dictionary, run_state: RunState) -> void:
	if run_state.is_terminal():
		run["stopped_reason"] = "terminal"
	run["final_bankroll"] = run_state.bankroll
	run["final_heat"] = run_state.suspicion_level()
	run["final_status"] = run_state.run_status
	run["failure_reason"] = run_state.run_failure_reason
	run["debt_balance"] = _total_debt_balance(run_state)
	run["debt_open_count"] = run_state.debt.size()
	run["estimated_minutes"] = snapped(float(run.get("estimated_seconds", 0.0)) / 60.0, 0.01)
	run["won"] = run_state.run_status == RunState.RUN_STATUS_ENDED and bool(run_state.narrative_flags.get("demo_victory", false))
	run["lost"] = run_state.run_status == RunState.RUN_STATUS_FAILED
	run["victory_route"] = str(run_state.narrative_flags.get("demo_victory_route", ""))
	if bool(run.get("showdown_attempted", false)) and bool(run_state.narrative_flags.get("grand_casino_showdown_success", false)):
		run["showdown_won"] = true
	if str(run.get("victory_route", "")).is_empty() and bool(run.get("won", false)):
		run["victory_route"] = "unknown_demo_victory"


func _build_aggregate(runs: Array, seeds_per_scenario: int, seed_prefix: String) -> Dictionary:
	var victory_routes := {}
	var failure_reasons := {}
	var scenario_rows: Array = []
	var policy_rows: Array = []
	var clean_runs: Array = []
	var cheat_runs: Array = []
	var debt_runs: Array = []
	var challenge_runs: Array = []
	var tier2_runs: Array = []
	var lender_runs: Array = []
	var showdown_runs: Array = []
	var minutes: Array = []
	for run_value in runs:
		if typeof(run_value) != TYPE_DICTIONARY:
			continue
		var run: Dictionary = run_value
		minutes.append(float(run.get("estimated_minutes", 0.0)))
		if bool(run.get("won", false)):
			var route := str(run.get("victory_route", "unknown"))
			victory_routes[route] = int(victory_routes.get(route, 0)) + 1
		elif bool(run.get("lost", false)):
			var reason := str(run.get("failure_reason", "unknown"))
			if reason.is_empty():
				reason = "unknown"
			failure_reasons[reason] = int(failure_reasons.get(reason, 0)) + 1
		else:
			failure_reasons["action_cap_or_active"] = int(failure_reasons.get("action_cap_or_active", 0)) + 1
		if int(run.get("cheat_actions", 0)) <= 0:
			clean_runs.append(run)
		else:
			cheat_runs.append(run)
		if str(run.get("policy", "")) == "debt":
			debt_runs.append(run)
		if bool(run.get("challenge_engaged", false)):
			challenge_runs.append(run)
		if int(run.get("tier2_visits", 0)) > 0:
			tier2_runs.append(run)
		if int(run.get("lender_uses", 0)) > 0:
			lender_runs.append(run)
		if bool(run.get("showdown_attempted", false)):
			showdown_runs.append(run)
	for scenario_value in SCENARIOS:
		var scenario: Dictionary = scenario_value
		var scenario_id := str(scenario.get("id", ""))
		scenario_rows.append(_summary_row(_filter_runs(runs, "scenario_id", scenario_id), scenario_id))
	for policy in ["clean", "tier2", "cheat", "debt"]:
		policy_rows.append(_summary_row(_filter_runs(runs, "policy", policy), policy))
	var total_count := runs.size()
	var won_count := _won_count(runs)
	var showdown_wins := _showdown_win_count(showdown_runs)
	return {
		"seed_prefix": seed_prefix,
		"seeds_per_scenario": seeds_per_scenario,
		"run_count": total_count,
		"victory_count": won_count,
		"victory_rate": _rate(won_count, total_count),
		"loss_count": _lost_count(runs),
		"active_or_capped_count": total_count - won_count - _lost_count(runs),
		"victory_routes": _count_dict_rows(victory_routes),
		"failure_reasons": _count_dict_rows(failure_reasons),
		"median_minutes": _median_float(minutes),
		"clean_split": _summary_row(clean_runs, "clean_no_cheat_actions"),
		"cheat_split": _summary_row(cheat_runs, "cheat_actions_used"),
		"debt_split": _summary_row(debt_runs, "debt_policy"),
		"challenge_split": _summary_row(challenge_runs, "challenge_runs"),
		"tier2_usage_count": tier2_runs.size(),
		"tier2_usage_rate": _rate(tier2_runs.size(), total_count),
		"lender_engagement_count": lender_runs.size(),
		"lender_engagement_rate": _rate(lender_runs.size(), total_count),
		"challenge_engagement_count": challenge_runs.size(),
		"challenge_engagement_rate": _rate(challenge_runs.size(), total_count),
		"showdown_attempts": showdown_runs.size(),
		"showdown_wins": showdown_wins,
		"showdown_win_rate": _rate(showdown_wins, showdown_runs.size()),
		"scenario_summaries": scenario_rows,
		"policy_summaries": policy_rows,
		"curve_samples": _curve_samples(runs),
	}


func _summary_row(runs: Array, label: String) -> Dictionary:
	var minutes: Array = []
	var final_bankrolls: Array = []
	var final_heat: Array = []
	var cheat_actions := 0
	var lender_uses := 0
	var tier2_visits := 0
	for run_value in runs:
		if typeof(run_value) != TYPE_DICTIONARY:
			continue
		var run: Dictionary = run_value
		minutes.append(float(run.get("estimated_minutes", 0.0)))
		final_bankrolls.append(float(run.get("final_bankroll", 0)))
		final_heat.append(float(run.get("final_heat", 0)))
		cheat_actions += int(run.get("cheat_actions", 0))
		lender_uses += int(run.get("lender_uses", 0))
		tier2_visits += int(run.get("tier2_visits", 0))
	var run_count := runs.size()
	return {
		"label": label,
		"run_count": run_count,
		"victory_count": _won_count(runs),
		"victory_rate": _rate(_won_count(runs), run_count),
		"loss_count": _lost_count(runs),
		"loss_rate": _rate(_lost_count(runs), run_count),
		"median_minutes": _median_float(minutes),
		"median_final_bankroll": _median_float(final_bankrolls),
		"median_final_heat": _median_float(final_heat),
		"cheat_actions": cheat_actions,
		"lender_uses": lender_uses,
		"tier2_visits": tier2_visits,
	}


func _assert_targets(aggregate: Dictionary) -> void:
	var victory_rate := float(aggregate.get("victory_rate", 0.0))
	if victory_rate < float(TARGETS["overall_victory_rate_min"]) or victory_rate > float(TARGETS["overall_victory_rate_max"]):
		failures.append("Overall victory rate %.2f outside target %.2f-%.2f." % [victory_rate, float(TARGETS["overall_victory_rate_min"]), float(TARGETS["overall_victory_rate_max"])])
	var median_minutes := float(aggregate.get("median_minutes", 0.0))
	if median_minutes < float(TARGETS["median_minutes_min"]) or median_minutes > float(TARGETS["median_minutes_max"]):
		failures.append("Median run %.2f minutes outside target %.2f-%.2f." % [median_minutes, float(TARGETS["median_minutes_min"]), float(TARGETS["median_minutes_max"])])
	var clean_split: Dictionary = _dict(aggregate.get("clean_split", {}))
	var clean_victory := float(clean_split.get("victory_rate", 0.0))
	if clean_victory < float(TARGETS["clean_victory_rate_min"]):
		failures.append("Clean/no-cheat victory rate %.2f below target %.2f." % [clean_victory, float(TARGETS["clean_victory_rate_min"])])
	var cheat_split: Dictionary = _dict(aggregate.get("cheat_split", {}))
	var cheat_victory := float(cheat_split.get("victory_rate", 0.0))
	if cheat_victory < float(TARGETS["cheat_victory_rate_min"]):
		failures.append("Cheat route victory rate %.2f below target %.2f." % [cheat_victory, float(TARGETS["cheat_victory_rate_min"])])
	var tier2_rate := float(aggregate.get("tier2_usage_rate", 0.0))
	if tier2_rate < float(TARGETS["tier2_usage_rate_min"]):
		failures.append("Tier-2 usage rate %.2f below target %.2f." % [tier2_rate, float(TARGETS["tier2_usage_rate_min"])])
	var lender_rate := float(aggregate.get("lender_engagement_rate", 0.0))
	if lender_rate < float(TARGETS["lender_engagement_rate_min"]):
		failures.append("Lender engagement rate %.2f below target %.2f." % [lender_rate, float(TARGETS["lender_engagement_rate_min"])])
	var challenge_rate := float(aggregate.get("challenge_engagement_rate", 0.0))
	if challenge_rate < float(TARGETS["challenge_engagement_rate_min"]):
		failures.append("Challenge engagement rate %.2f below target %.2f." % [challenge_rate, float(TARGETS["challenge_engagement_rate_min"])])
	var debt_split: Dictionary = _dict(aggregate.get("debt_split", {}))
	var debt_loss_rate := float(debt_split.get("loss_rate", 0.0))
	if debt_loss_rate > float(TARGETS["debt_terminal_failure_rate_max"]):
		failures.append("Debt policy terminal failure rate %.2f above target %.2f." % [debt_loss_rate, float(TARGETS["debt_terminal_failure_rate_max"])])
	var showdown_attempts := int(aggregate.get("showdown_attempts", 0))
	var showdown_min_attempts := int(TARGETS["showdown_min_attempts_for_rate"])
	if showdown_attempts >= showdown_min_attempts:
		var showdown_rate := float(aggregate.get("showdown_win_rate", 0.0))
		if showdown_rate < float(TARGETS["showdown_win_rate_min"]) or showdown_rate > float(TARGETS["showdown_win_rate_max"]):
			failures.append("Showdown win rate %.2f outside target %.2f-%.2f." % [showdown_rate, float(TARGETS["showdown_win_rate_min"]), float(TARGETS["showdown_win_rate_max"])])
	elif showdown_attempts > 0:
		warnings.append("Showdown win rate sample skipped target enforcement: %d/%d attempts." % [showdown_attempts, showdown_min_attempts])


func _curve_samples(runs: Array) -> Array:
	var rows: Array = []
	for percent in [0, 25, 50, 75, 100]:
		var bankrolls: Array = []
		var heats: Array = []
		var debts: Array = []
		for run_value in runs:
			if typeof(run_value) != TYPE_DICTIONARY:
				continue
			var run: Dictionary = run_value
			var curve := _array(run.get("curve", []))
			if curve.is_empty():
				continue
			var index := clampi(int(round(float(curve.size() - 1) * float(percent) / 100.0)), 0, curve.size() - 1)
			var point: Dictionary = _dict(curve[index])
			bankrolls.append(float(point.get("bankroll", 0)))
			heats.append(float(point.get("heat", 0)))
			debts.append(float(point.get("debt_balance", 0)))
		rows.append({
			"percent": percent,
			"median_bankroll": _median_float(bankrolls),
			"median_heat": _median_float(heats),
			"median_debt_balance": _median_float(debts),
		})
	return rows


func _write_json(path: String, report: Dictionary) -> void:
	var file_path := path
	if file_path.begins_with("res://"):
		var directory := file_path.get_base_dir()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write metrics JSON: %s" % file_path)
		return
	file.store_string(JSON.stringify(report, "\t"))


func _write_markdown(path: String, report: Dictionary) -> void:
	if path.begins_with("res://"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var aggregate: Dictionary = _dict(report.get("aggregate", {}))
	var lines: Array = []
	lines.append("# Act 1 Endgame Metrics Probe")
	lines.append("")
	lines.append("- Deterministic: true")
	lines.append("- Seed prefix: `%s`" % str(report.get("seed_prefix", "")))
	lines.append("- Seeds per scenario: %d" % int(report.get("seeds_per_scenario", 0)))
	lines.append("- Runs: %d" % int(report.get("run_count", 0)))
	lines.append("- Passed targets: %s" % str(report.get("passed", false)))
	lines.append("- Overall victory rate: %.2f" % float(aggregate.get("victory_rate", 0.0)))
	lines.append("- Median estimated run length: %.2f minutes" % float(aggregate.get("median_minutes", 0.0)))
	lines.append("- Tier-2 usage: %.2f" % float(aggregate.get("tier2_usage_rate", 0.0)))
	lines.append("- Lender engagement: %.2f" % float(aggregate.get("lender_engagement_rate", 0.0)))
	lines.append("- Challenge engagement: %.2f" % float(aggregate.get("challenge_engagement_rate", 0.0)))
	lines.append("- Showdown win rate: %.2f (%d/%d)" % [float(aggregate.get("showdown_win_rate", 0.0)), int(aggregate.get("showdown_wins", 0)), int(aggregate.get("showdown_attempts", 0))])
	lines.append("")
	lines.append("## Scenario Summary")
	lines.append("")
	lines.append("| Scenario | Runs | Victory % | Loss % | Median min | Median bankroll | Median heat | Cheats | Lenders | Tier-2 visits |")
	lines.append("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
	for row_value in _array(aggregate.get("scenario_summaries", [])):
		var row: Dictionary = _dict(row_value)
		lines.append("| %s | %d | %.2f | %.2f | %.2f | %.2f | %.2f | %d | %d | %d |" % [
			str(row.get("label", "")),
			int(row.get("run_count", 0)),
			float(row.get("victory_rate", 0.0)),
			float(row.get("loss_rate", 0.0)),
			float(row.get("median_minutes", 0.0)),
			float(row.get("median_final_bankroll", 0.0)),
			float(row.get("median_final_heat", 0.0)),
			int(row.get("cheat_actions", 0)),
			int(row.get("lender_uses", 0)),
			int(row.get("tier2_visits", 0)),
		])
	lines.append("")
	lines.append("## Victory Routes")
	lines.append("")
	lines.append("| Route | Count |")
	lines.append("|---|---:|")
	for row_value in _array(aggregate.get("victory_routes", [])):
		var route_row: Dictionary = _dict(row_value)
		lines.append("| %s | %d |" % [str(route_row.get("key", "")), int(route_row.get("count", 0))])
	lines.append("")
	lines.append("## Failure Reasons")
	lines.append("")
	lines.append("| Reason | Count |")
	lines.append("|---|---:|")
	for row_value in _array(aggregate.get("failure_reasons", [])):
		var failure_row: Dictionary = _dict(row_value)
		lines.append("| %s | %d |" % [str(failure_row.get("key", "")), int(failure_row.get("count", 0))])
	lines.append("")
	lines.append("## Curve Samples")
	lines.append("")
	lines.append("| Run % | Median bankroll | Median heat | Median debt |")
	lines.append("|---:|---:|---:|---:|")
	for row_value in _array(aggregate.get("curve_samples", [])):
		var curve_row: Dictionary = _dict(row_value)
		lines.append("| %d | %.2f | %.2f | %.2f |" % [
			int(curve_row.get("percent", 0)),
			float(curve_row.get("median_bankroll", 0.0)),
			float(curve_row.get("median_heat", 0.0)),
			float(curve_row.get("median_debt_balance", 0.0)),
		])
	lines.append("")
	lines.append("## Target Failures")
	lines.append("")
	if failures.is_empty():
		lines.append("- none")
	else:
		for failure in failures:
			lines.append("- %s" % str(failure))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write metrics markdown: %s" % path)
		return
	file.store_string("\n".join(lines))


func _print_summary(output_json: String, output_markdown: String, aggregate: Dictionary) -> void:
	print("ENDGAME_METRICS status=%s runs=%d victory_rate=%.2f median_minutes=%.2f tier2_rate=%.2f lender_rate=%.2f challenge_rate=%.2f showdown=%d/%d" % [
		"PASS" if failures.is_empty() else "FAIL",
		int(aggregate.get("run_count", 0)),
		float(aggregate.get("victory_rate", 0.0)),
		float(aggregate.get("median_minutes", 0.0)),
		float(aggregate.get("tier2_usage_rate", 0.0)),
		float(aggregate.get("lender_engagement_rate", 0.0)),
		float(aggregate.get("challenge_engagement_rate", 0.0)),
		int(aggregate.get("showdown_wins", 0)),
		int(aggregate.get("showdown_attempts", 0)),
	])
	print("ENDGAME_METRICS_JSON %s" % output_json)
	print("ENDGAME_METRICS_MARKDOWN %s" % output_markdown)
	for failure in failures:
		push_error(str(failure))


func _filter_runs(runs: Array, key: String, value: String) -> Array:
	var result: Array = []
	for run_value in runs:
		if typeof(run_value) == TYPE_DICTIONARY and str((run_value as Dictionary).get(key, "")) == value:
			result.append(run_value)
	return result


func _won_count(runs: Array) -> int:
	var count := 0
	for run_value in runs:
		if typeof(run_value) == TYPE_DICTIONARY and bool((run_value as Dictionary).get("won", false)):
			count += 1
	return count


func _lost_count(runs: Array) -> int:
	var count := 0
	for run_value in runs:
		if typeof(run_value) == TYPE_DICTIONARY and bool((run_value as Dictionary).get("lost", false)):
			count += 1
	return count


func _showdown_win_count(runs: Array) -> int:
	var count := 0
	for run_value in runs:
		if typeof(run_value) == TYPE_DICTIONARY and bool((run_value as Dictionary).get("showdown_won", false)):
			count += 1
	return count


func _count_dict_rows(counts: Dictionary) -> Array:
	var keys: Array = counts.keys()
	keys.sort()
	var rows: Array = []
	for key_value in keys:
		var key := str(key_value)
		rows.append({"key": key, "count": int(counts.get(key, 0))})
	return rows


func _rate(numerator: int, denominator: int) -> float:
	if denominator <= 0:
		return 0.0
	return snapped(float(numerator) / float(denominator), 0.0001)


func _median_float(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var numbers: Array = []
	for value in values:
		numbers.append(float(value))
	numbers.sort()
	var mid := numbers.size() / 2
	if numbers.size() % 2 == 1:
		return snapped(float(numbers[mid]), 0.01)
	return snapped((float(numbers[mid - 1]) + float(numbers[mid])) / 2.0, 0.01)


func _total_debt_balance(run_state: RunState) -> int:
	var total := 0
	for debt_value in run_state.debt:
		if typeof(debt_value) == TYPE_DICTIONARY:
			total += maxi(0, int((debt_value as Dictionary).get("balance", 0)))
	return total


func _metrics_showdown_roll(run: Dictionary) -> int:
	var seed := "%s:%s:%s" % [str(run.get("seed", "")), str(run.get("policy", "")), str(run.get("scenario_id", ""))]
	return int(_stable_hash(seed) % 90) + 1


func _stable_hash(text: String) -> int:
	var value := 2166136261
	for index in range(text.length()):
		value = int((value ^ text.unicode_at(index)) * 16777619) & 0x7fffffff
	return maxi(1, value)


func _archetype(archetype_id: String) -> Dictionary:
	for archetype_value in library.environment_archetypes:
		if typeof(archetype_value) == TYPE_DICTIONARY and str((archetype_value as Dictionary).get("id", "")) == archetype_id:
			return (archetype_value as Dictionary).duplicate(true)
	return {}


func _archetype_tier(archetype_id: String) -> int:
	return int(_archetype(archetype_id).get("tier", 1))


func _archetype_kind(archetype_id: String) -> String:
	return str(_archetype(archetype_id).get("kind", ""))


func _action_ids(actions: Array) -> Array:
	var result: Array = []
	for action_value in actions:
		if typeof(action_value) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_value
		var action_id := str(action.get("id", ""))
		if not action_id.is_empty():
			result.append(action_id)
	return result


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		var text := str(entry).strip_edges()
		if not text.is_empty():
			result.append(text)
	return result


func _unique_strings(values: Array) -> Array:
	var result: Array = []
	for value in values:
		var text := str(value).strip_edges()
		if not text.is_empty() and not result.has(text):
			result.append(text)
	return result


func _array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
