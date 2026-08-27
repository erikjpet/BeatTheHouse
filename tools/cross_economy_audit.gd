extends "res://tools/endgame_metrics_probe.gd"

# Opt-in, seeded 0.6 cross-system economy audit. The ordinary game/travel/event
# paths reuse endgame_metrics_probe's production drivers. Specialized strategies
# use the production RunState state machines while modeling only human contact
# selection at explicit action boundaries. Jobs, the Numbers, and The Count's
# tables/deliveries settle through production.

const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")

const TOOL_ID := "cross_economy_audit_v1"
const DEFAULT_SEEDS_PER_STYLE := 64
const DEFAULT_MAX_ACTIONS := 208
const AUDIT_DEFAULT_SEED_PREFIX := "BALANCE06-1"
const DEFAULT_OUTPUT := "res://.tmp/balance06_1/cross_economy_audit.json"
const DEBT_THRESHOLDS := [1, 25, 45, 90]
const SPECIALIST_ACTION_BUDGET := 64
const NUMBERS_SPECIALIST_ACTION_BUDGET := 112
const PUSHER_DROP_BUDGET := 64
const PLAYSTYLES := [
	{"id": "control_crew_ignoring", "policy": "clean", "label": "Crew-ignoring 0.5-compatible control"},
	{"id": "pure_gambler", "policy": "clean", "label": "Pure gambler"},
	{"id": "crew_maximizer", "policy": "tier2", "label": "Crew job maximizer"},
	{"id": "numbers_specialist", "policy": "clean", "label": "Numbers specialist"},
	{"id": "coin_pusher_grinder", "policy": "clean", "label": "Persisted coin-pusher grinder"},
	{"id": "cheater", "policy": "cheat", "label": "Cheater"},
	{"id": "heist_rusher", "policy": "clean", "label": "The Count heist rusher"},
	{"id": "mixed_opportunist", "policy": "tier2", "label": "Mixed opportunist"},
]

var _active_style := ""


func _run() -> void:
	var options := _audit_options()
	var seeds_per_style := maxi(1, int(options.get("seeds_per_style", DEFAULT_SEEDS_PER_STYLE)))
	var max_actions := maxi(8, int(options.get("max_actions", DEFAULT_MAX_ACTIONS)))
	var seed_prefix := str(options.get("seed_prefix", AUDIT_DEFAULT_SEED_PREFIX)).strip_edges()
	var style_filter := str(options.get("playstyle", "")).strip_edges()
	var output := str(options.get("output", DEFAULT_OUTPUT)).strip_edges()
	var build_ref := str(options.get("build_ref", "UNSPECIFIED")).strip_edges()

	library = ContentLibraryScript.new()
	library.load(false)
	for error_value in library.validation_errors:
		failures.append("Content validation error: %s" % str(error_value))
	for warning_value in library.validation_warnings:
		warnings.append("Content validation warning: %s" % str(warning_value))
	generator = RunGeneratorScript.new(library)
	_build_game_modules()

	var runs: Array = []
	for style_value in PLAYSTYLES:
		var style: Dictionary = style_value
		if not style_filter.is_empty() and style_filter != str(style.get("id", "")):
			continue
		for seed_index in range(seeds_per_style):
			var seed := "%s-%s-%03d" % [seed_prefix, str(style.get("id", "")), seed_index + 1]
			runs.append(_simulate_audit_run(style, seed, max_actions))

	var report := {
		"tool": TOOL_ID,
		"build_ref": build_ref,
		"deterministic": true,
		"clock_model": "RunState action boundaries only; no wall-clock reads",
		"seed_prefix": seed_prefix,
		"seeds_per_playstyle": seeds_per_style,
		"playstyle_filter": style_filter,
		"max_actions": max_actions,
		"run_count": runs.size(),
		"playstyles": PLAYSTYLES,
		"specialized_driver_contract": {
			"ordinary_games_travel_events_services_lenders_endgame": "production module and RunState paths inherited from endgame_metrics_probe.gd",
			"crew_jobs": "one-boundary deterministic contact selection; production acceptance, delivery/stake play, route cost/risk, resolution, trust, and cash",
			"numbers": "production fix bribe delivery, camouflage allocation, slip settlement/payday, and ordinary slip purchase paths",
			"coin_pusher": "paid travel to a naturally generated gas-station room; grind only when the seed offers a pusher; never reset; real drops, fixed-tick patches, and post-drop COLLECT",
			"heist": "route-conditioned by injected audit_night only; production lock, blackjack identity/play, schedule/cart delivery, route cost/risk, getaway, and terminal payout paths",
		},
		"measurement_interpretation": {
			"censoring": "Action-cap survivors remain active RunState observations and are excluded from observed-terminal pressure/choice denominators.",
			"specialization_budget": "Crew specializes through action 64, Numbers through action 112 after one real runner route, and pusher for 64 paid drops. They then return to the ordinary endgame driver so the global cap is a censoring guard rather than their planned ending.",
			"pusher": "Unconditional natural availability plus reached-machine conditional distributions.",
			"specialists": "Runs dynamically record conditioning when the policy selects a desired Crew contact who was not naturally present; such times are route-conditioned, not natural opportunity rates.",
			"heist": "Completion distributions are conditional on audit_night and any recorded contact selection; they must not be read as natural opportunity frequency.",
			"legacy_control": "Current quantitative control plus separate two-seed 0.5 structural compatibility evidence; no historical distribution inference.",
		},
		"source_register": _source_register(),
		"aggregate": _audit_aggregate(runs, max_actions),
		"runs": runs,
		"failures": failures,
		"warnings": warnings,
		"passed": failures.is_empty() and not runs.is_empty(),
	}
	var wrote_report := _write_audit_json(output, report)
	var aggregate := _dict(report.get("aggregate", {}))
	var passed := bool(report["passed"]) and wrote_report
	print("CROSS_ECONOMY_AUDIT_%s runs=%d styles=%d output=%s" % ["PASS" if passed else "FAIL", runs.size(), _array(aggregate.get("playstyles", [])).size(), ProjectSettings.globalize_path(output)])
	await _finish(0 if passed else 1)


func _audit_options() -> Dictionary:
	var options := {}
	for arg_value in OS.get_cmdline_user_args():
		var arg := str(arg_value)
		if arg.begins_with("--seeds-per-style="):
			options["seeds_per_style"] = int(arg.trim_prefix("--seeds-per-style="))
		elif arg.begins_with("--max-actions="):
			options["max_actions"] = int(arg.trim_prefix("--max-actions="))
		elif arg.begins_with("--seed-prefix="):
			options["seed_prefix"] = arg.trim_prefix("--seed-prefix=")
		elif arg.begins_with("--playstyle="):
			options["playstyle"] = arg.trim_prefix("--playstyle=")
		elif arg.begins_with("--output="):
			options["output"] = arg.trim_prefix("--output=")
		elif arg.begins_with("--build-ref="):
			options["build_ref"] = arg.trim_prefix("--build-ref=")
	return options


func _source_register() -> Dictionary:
	var games := _json_array("res://data/games/games.json")
	var items := _json_array("res://data/items/items.json")
	var events := _json_array("res://data/events/events.json")
	return {
		"contract": "Exact data-defined economy register; production module paths remain authoritative for full-simulation paytables.",
		"economy_checkpoint": _json_value("res://data/economy/content06_1_audit.json"),
		"games": games,
		"crew_jobs": _json_array("res://data/crew/jobs.json"),
		"crew_plays": _json_value("res://data/crew/plays.json"),
		"numbers": _json_value("res://data/crew/numbers.json"),
		"heists": _json_value("res://data/crew/heist.json"),
		"items": items,
		"services": _json_array("res://data/services/services.json"),
		"lenders": _json_array("res://data/debt/lenders.json"),
		"travel_routes": _json_array("res://data/travel/routes.json"),
		"events": events,
		"legacy_control_baseline": _json_value("res://scripts/tests/fixtures/crew06_5_ignored_run_baseline.json"),
	}


func _json_value(path: String) -> Variant:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		failures.append("Could not parse source-register file: %s" % path)
		return {}
	return parsed


func _json_array(path: String) -> Array:
	return _array(_json_value(path))


func _simulate_audit_run(style: Dictionary, seed: String, max_actions: int) -> Dictionary:
	_active_style = str(style.get("id", ""))
	# A UI run owns a fresh module lifetime. Replace only the stateful pusher
	# module per seed so completed live simulations do not accumulate across the
	# 512-run audit process.
	game_modules.erase("coin_pusher")
	var pusher_game := _create_game_module(library.game("coin_pusher"))
	if pusher_game != null:
		# The production module persists one live cabinet per room/context. Give
		# every audit run a deterministic context so a machine persists within a
		# seed but never leaks opening stock or physics state into the next seed.
		pusher_game.set_transient_state_key_context("balance06_1:%s" % seed)
		game_modules["coin_pusher"] = pusher_game
	var policy := str(style.get("policy", "clean"))
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed, RunStateScript.standard_challenge(seed))
	generator.next_environment(run_state)
	var run := {
		"seed": seed,
		"playstyle": _active_style,
		"policy": policy,
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
		"grand_casino_entries": 0,
		"route_cost_total": 0,
		"service_use_keys": {},
		"showdown_attempted": false,
		"showdown_won": false,
		"showdown_trace": [],
		"duel_attempted": false,
		"duel_hands": 0,
		"duel_callouts": 0,
		"duel_correct_callouts": 0,
		"duel_false_callouts": 0,
		"duel_outcome": "",
		"duel_margin": 0,
		"pat_down_tier": "",
		"players_card_highest_tier": "none",
		"players_card_comp_uses": 0,
		"grand_casino_chip_buys": 0,
		"grand_casino_chip_cashouts": 0,
		"grand_casino_room_moves": 0,
		"rourke_watched_actions_avoided": 0,
		"rourke_clear_cheat_actions": 0,
		"stopped_reason": "action_cap",
		"failure_reason": "",
		"victory_route": "",
		"conditioned_probe": false,
		"conditioning": "none",
		"pusher_machine_reached": false,
		"pusher_variation": "",
		"curve": [],
		"visited_archetypes": [],
		"travel_decisions": [],
		"game_mix": {},
		"ledger": [],
		"source_totals": {},
		"sink_totals": {},
		"first_debt_action": {},
		"first_bankroll_action": {},
		"first_heat_50_action": -1,
		"first_heat_80_action": -1,
		"victory_action": -1,
		"peak_bankroll": run_state.bankroll,
		"minimum_bankroll": run_state.bankroll,
		"peak_heat": run_state.suspicion_level(),
		"peak_debt": 0,
		"style_state": {},
	}
	_prepare_style_fixture(run_state, run)
	_record_curve(run, run_state, "start")
	_record_visit(run, run_state)

	for _action_index in range(max_actions):
		if run_state.is_terminal():
			break
		var before_bankroll := run_state.bankroll
		var before_heat := run_state.suspicion_level()
		var before_debt := _total_debt_balance(run_state)
		var label := _try_style_action(run_state, run, policy)
		if label.is_empty():
			label = _try_general_action(run_state, run, policy)
		if label.is_empty():
			run_state.advance_environment_turns(1)
			label = "idle"
			_count_action(run, "idle")
		_record_economy_boundary(run, run_state, label, before_bankroll, before_heat, before_debt)
		_record_curve(run, run_state, label)
		_record_thresholds(run, run_state)

	if not run_state.is_terminal():
		run["stopped_reason"] = "censored_action_cap"
	else:
		run["stopped_reason"] = "terminal"
	_finalize_run(run, run_state)
	run["censored"] = not run_state.is_terminal()
	run["pressure_terminal"] = _is_pressure_terminal(run)
	run["choice_terminal"] = bool(run.get("won", false)) or str(run.get("failure_reason", "")) == RunState.FAILURE_ABANDONED
	return run


func _prepare_style_fixture(run_state: RunState, run: Dictionary) -> void:
	match _active_style:
		"coin_pusher_grinder":
			_prepare_pusher(run_state, run)
		"heist_rusher":
			_mark_conditioning(run, "The Count route is conditioned on audit_night; rank, costs, play, and terminal resolution remain production-owned.")
			var hooks := _dict(run_state.current_environment.get("scenario_hook_flags", {}))
			hooks["audit_night"] = true
			run_state.current_environment["scenario_hook_flags"] = hooks
			run_state.store_current_world_node_environment()


func _try_style_action(run_state: RunState, run: Dictionary, policy: String) -> String:
	match _active_style:
		"crew_maximizer":
			if int(run.get("actions", 0)) < SPECIALIST_ACTION_BUDGET:
				return _crew_job_boundary(run_state, run, "crew_bishop", "inner_circle", true)
		"numbers_specialist":
			if int(run.get("actions", 0)) < NUMBERS_SPECIALIST_ACTION_BUDGET:
				return _numbers_boundary(run_state, run)
		"coin_pusher_grinder":
			if int(_dict(run.get("style_state", {})).get("drops", 0)) < PUSHER_DROP_BUDGET:
				return _pusher_boundary(run_state, run)
		"heist_rusher":
			return _heist_boundary(run_state, run)
		"mixed_opportunist":
			if int(run.get("actions", 0)) % 7 == 0:
				return _crew_job_boundary(run_state, run, "crew_switch", "made", false)
			if int(run.get("actions", 0)) % 11 == 0 and run_state.bankroll >= 60:
				return _buy_numbers_slip_boundary(run_state, run, "mixed_numbers_slip")
		_:
			pass
	return ""


func _try_general_action(run_state: RunState, run: Dictionary, policy: String) -> String:
	if _try_claim_or_resolve_endgame(run_state, run):
		_count_action(run, "event")
		if run_state.is_terminal():
			run["victory_action"] = int(run.get("actions", 0))
		return "endgame"
	if _try_resolve_required_progression_event(run_state, run, policy):
		_count_action(run, "event")
		return "progression"
	if _active_style != "pure_gambler" and _try_use_grand_casino_facility(run_state, run, policy):
		_count_action(run, "hook")
		_record_visit(run, run_state)
		return "casino_facility"
	var inventory_before := _string_array(run_state.inventory)
	if _active_style in ["control_crew_ignoring", "mixed_opportunist"] and _try_buy_helpful_item(run_state, run, policy):
		_count_action(run, "item")
		return "item:%s" % _added_string(inventory_before, _string_array(run_state.inventory), "unknown")
	var services_before := _dict(run.get("service_use_keys", {}))
	if _active_style in ["control_crew_ignoring", "mixed_opportunist", "cheater"] and _try_use_pressure_service(run_state, run, policy):
		_count_action(run, "hook")
		return "service:%s" % _incremented_map_key(services_before, _dict(run.get("service_use_keys", {})), "unknown")
	if _active_style != "pure_gambler" and _try_use_lender(run_state, run, policy):
		_count_action(run, "hook")
		return "lender"
	if _should_travel_now(run_state, run, policy) and _try_travel(run_state, run, policy):
		_count_action(run, "travel")
		_record_visit(run, run_state)
		return "travel:%s" % str(run_state.current_environment.get("archetype_id", "unknown"))
	var game_mix_before := _dict(run.get("game_mix", {}))
	if _try_play_game(run_state, run, policy):
		_count_action(run, "game")
		return "game:%s" % _incremented_map_key(game_mix_before, _dict(run.get("game_mix", {})), "unknown")
	if _active_style in ["control_crew_ignoring", "mixed_opportunist"] and _try_resolve_event(run_state, run, policy):
		_count_action(run, "event")
		return "event"
	if _try_travel(run_state, run, policy):
		_count_action(run, "travel")
		_record_visit(run, run_state)
		return "travel:%s" % str(run_state.current_environment.get("archetype_id", "unknown"))
	return ""


func _incremented_map_key(before: Dictionary, after: Dictionary, fallback: String) -> String:
	for key_value in after.keys():
		var key := str(key_value)
		if int(after.get(key_value, 0)) > int(before.get(key, 0)):
			return key
	return fallback


func _added_string(before: Array, after: Array, fallback: String) -> String:
	for value in after:
		var text := str(value)
		if not before.has(text):
			return text
	return fallback


func _crew_job_boundary(run_state: RunState, run: Dictionary, member_id: String, target_rank: String, keep_working: bool) -> String:
	var state := _dict(run.get("style_state", {}))
	var pending_job_id := str(state.get("pending_job_id", ""))
	if not pending_job_id.is_empty():
		var job := _dict(run_state.crew_jobs.get(pending_job_id, {}))
		var status := str(job.get("status", ""))
		if status == "resolved":
			state.erase("pending_job_id")
			run["style_state"] = state
			return _crew_job_boundary(run_state, run, member_id, target_rank, keep_working)
		if run_state.delivery_has_active_run():
			return _drive_active_delivery_boundary(run_state, run, "crew_job:%s" % str(job.get("definition_id", "unknown")))
		if str(job.get("kind", "")) == "stake_horse":
			return _drive_stake_job_boundary(run_state, run, job)
		if str(job.get("kind", "")) == "collection":
			var collected := run_state.crew_resolve_collection("friendly")
			if bool(collected.get("ok", false)):
				run_state.advance_environment_turns(1)
				_count_action(run, "hook")
				return "crew_job:%s:collection" % str(job.get("definition_id", "unknown"))
		return ""
	if run_state.crew_rank(member_id) == "stranger" or run_state.crew_rank(member_id) == "marker":
		var recruited := run_state.crew_recruit_member(member_id)
		if not bool(recruited.get("ok", false)):
			return ""
		run_state.advance_environment_turns(1)
		_count_action(run, "hook")
		return "crew_recruitment_gate"
	var rank_index := CrewStateModelScript.RANK_IDS.find(run_state.crew_rank(member_id))
	var target_index := CrewStateModelScript.RANK_IDS.find(target_rank)
	if rank_index >= target_index and not keep_working:
		return ""
	var definition := _best_job_for_member(member_id, run_state.crew_rank(member_id), run_state.current_world_node_id())
	if definition.is_empty():
		return ""
	# Contact/presence is the one human-search adapter in this route. Acceptance,
	# delivery, stakes, game settlement, rewards, trust, and route costs all flow
	# through the production RunState paths after this one-boundary contact.
	var original_presence := _array(run_state.current_environment.get("crew_presence", []))
	var contact_presence := original_presence.duplicate(true)
	var naturally_present := contact_presence.any(func(value: Variant) -> bool: return typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("member_id", "")) == member_id)
	if not naturally_present:
		_mark_conditioning(run, "Desired-member contact availability is selected at one action boundary; production acceptance and consequences follow.")
		contact_presence.append({"member_id": member_id})
	run_state.current_environment["crew_presence"] = contact_presence
	var accepted := run_state.crew_job_accept_definition(str(definition.get("id", "")))
	run_state.current_environment["crew_presence"] = original_presence
	var job_id := str(accepted.get("job_id", ""))
	if not bool(accepted.get("ok", false)) or job_id.is_empty():
		return ""
	state["pending_job_id"] = job_id
	run["style_state"] = state
	run_state.advance_environment_turns(1)
	_count_action(run, "hook")
	return "crew_job_accept"


func _mark_conditioning(run: Dictionary, note: String) -> void:
	run["conditioned_probe"] = true
	var existing := str(run.get("conditioning", "none"))
	if existing == "none" or existing.is_empty():
		run["conditioning"] = note
	elif not existing.contains(note):
		run["conditioning"] = "%s %s" % [existing, note]


func _best_job_for_member(member_id: String, rank_id: String, current_node_id: String) -> Dictionary:
	var rank_index := CrewStateModelScript.RANK_IDS.find(rank_id)
	var best := {}
	var best_cash := -1
	for value in CrewStateModelScript.job_definitions_for_member(member_id):
		var definition := _dict(value)
		if str(definition.get("id", "")) == "crew_favor_delivery":
			continue
		if CrewStateModelScript.RANK_IDS.find(str(definition.get("min_rank", "associate"))) > rank_index:
			continue
		var requested_nodes := _string_array(_dict(definition.get("payload", {})).get("target_node_ids", []))
		if str(definition.get("kind", "")) in ["package_run", "package_delivery", "numbers_route", "lookout_hold"] and requested_nodes.has(current_node_id):
			continue
		var cash := int(_dict(definition.get("rewards", {})).get("cash", 0))
		if str(definition.get("kind", "")) == "collection":
			cash = int(_dict(definition.get("payload", {})).get("friendly_cash", 0))
		if cash > best_cash:
			best_cash = cash
			best = definition
	return best


func _crew_at_least_rank(run_state: RunState, member_id: String, target_rank: String) -> bool:
	return CrewStateModelScript.RANK_IDS.find(run_state.crew_rank(member_id)) >= CrewStateModelScript.RANK_IDS.find(target_rank)


func _drive_stake_job_boundary(run_state: RunState, run: Dictionary, job: Dictionary) -> String:
	var payload := _dict(job.get("payload", {}))
	var definition_id := str(job.get("definition_id", "unknown"))
	if bool(payload.get("loss_choice_pending", false)):
		var resolved := run_state.crew_resolve_stake_horse_loss("repay")
		if bool(resolved.get("ok", false)):
			run_state.advance_environment_turns(1)
			_count_action(run, "hook")
			return "crew_job:%s:stake_repay" % definition_id
		return ""
	var venue_id := str(payload.get("venue_id", ""))
	if str(run_state.current_environment.get("archetype_id", "")) != venue_id:
		var target_node_id := _world_node_for_archetype(run_state, venue_id)
		return _travel_to_node_boundary(run_state, run, target_node_id, false, "crew_job:%s:stake_travel" % definition_id)
	return _play_specific_game_boundary(run_state, run, str(payload.get("game_id", "")), "clean", 0, "crew_job:%s:stake_play" % definition_id)


func _world_node_for_archetype(run_state: RunState, archetype_id: String) -> String:
	for node_value in _array(run_state.world_map.get("nodes", [])):
		var node := _dict(node_value)
		if str(node.get("archetype_id", "")) == archetype_id:
			return str(node.get("id", ""))
	return ""


func _apply_travel_choice(run_state: RunState, run: Dictionary, choice: Dictionary) -> bool:
	var route_cost_before := int(run.get("route_cost_total", 0))
	var traveled := super._apply_travel_choice(run_state, run, choice)
	if traveled:
		run["route_cost_total"] = route_cost_before + maxi(0, int(choice.get("cost", 0)))
	return traveled


func _drive_active_delivery_boundary(run_state: RunState, run: Dictionary, label_prefix: String) -> String:
	if not run_state.delivery_has_active_run():
		return ""
	var snapshot := run_state.delivery_snapshot()
	var target_node_id := str(snapshot.get("handoff_pending_node_id", ""))
	if target_node_id.is_empty():
		for target_value in _array(snapshot.get("targets", [])):
			var target := _dict(target_value)
			if str(target.get("status", "pending")) == "pending":
				target_node_id = str(target.get("node_id", ""))
				break
	if target_node_id.is_empty():
		return ""
	if run_state.current_world_node_id() != target_node_id:
		return _travel_to_node_boundary(run_state, run, target_node_id, true, "%s_travel" % label_prefix)
	var interaction := run_state.delivery_arrival_interaction()
	if not interaction.is_empty():
		run_state.delivery_complete_handoff(target_node_id)
	else:
		run_state.advance_environment_turns(1)
		interaction = run_state.delivery_arrival_interaction()
		if not interaction.is_empty():
			run_state.delivery_complete_handoff(target_node_id)
	_count_action(run, "hook")
	return "%s_work" % label_prefix


func _travel_to_node_boundary(run_state: RunState, run: Dictionary, target_node_id: String, delivery_active: bool, label: String) -> String:
	if target_node_id.is_empty() or run_state.current_world_node_id() == target_node_id:
		return ""
	var selected := {}
	var choices := _travel_choices(run_state)
	for choice_value in choices:
		var choice := _dict(choice_value)
		if str(choice.get("id", "")) == target_node_id and bool(choice.get("enabled", false)) and int(choice.get("cost", 0)) <= run_state.bankroll:
			selected = choice
			break
	if selected.is_empty() and run_state.has_world_map():
		var path := WorldMapScript.path_between(run_state.world_map, run_state.current_world_node_id(), target_node_id, false)
		for path_index in range(path.size() - 1, 0, -1):
			var waypoint_id := str(path[path_index])
			for choice_value in choices:
				var choice := _dict(choice_value)
				if str(choice.get("id", "")) == waypoint_id and bool(choice.get("enabled", false)) and int(choice.get("cost", 0)) <= run_state.bankroll:
					selected = choice
					break
			if not selected.is_empty():
				break
	if selected.is_empty():
		return ""
	var selected_target_id := str(selected.get("id", ""))
	var route := _dict(selected.get("route", {}))
	var route_status := _dict(selected.get("status", {}))
	route["cost"] = int(selected.get("cost", route.get("cost", 0)))
	if route_status.has("suspicion_delta"):
		route["suspicion_delta"] = int(route_status.get("suspicion_delta", route.get("suspicion_delta", 0)))
	var previous_environment := run_state.current_environment.duplicate(true)
	var route_risk := run_state.travel_route_risk(route, selected_target_id)
	var travel_heat := run_state.begin_travel_suspicion_decay(route, selected_target_id)
	generator.next_environment(run_state, selected_target_id, true)
	var travel_decay := run_state.finish_travel_suspicion_decay(travel_heat)
	var arrival := run_state.delivery_resolve_travel_arrival(route, route_risk) if delivery_active else {}
	var result := _travel_result(selected_target_id, previous_environment, run_state.current_environment, route, travel_decay, route_risk)
	GameModule.apply_result(run_state, result)
	if not delivery_active:
		run_state.advance_environment_turns(1)
	elif bool(arrival.get("handoff_ready", false)):
		run_state.delivery_complete_handoff(selected_target_id)
	run["travel_count"] = int(run.get("travel_count", 0)) + 1
	run["route_cost_total"] = int(run.get("route_cost_total", 0)) + maxi(0, int(selected.get("cost", route.get("cost", 0))))
	if str(run_state.current_environment.get("archetype_id", "")) == GRAND_CASINO_ID:
		run["grand_casino_entries"] = int(run.get("grand_casino_entries", 0)) + 1
	_record_visit(run, run_state)
	_count_action(run, "travel")
	return label


func _play_specific_game_boundary(run_state: RunState, run: Dictionary, game_id: String, policy: String, forced_stake: int, label: String) -> String:
	if not _string_array(run_state.current_environment.get("game_ids", [])).has(game_id):
		return ""
	var game: GameModule = game_modules.get(game_id, null)
	if game == null:
		return ""
	var action_id := _pick_game_action_id(game, run_state, run_state.current_environment, policy)
	if action_id.is_empty():
		return ""
	var stake := forced_stake if forced_stake > 0 else _stake_for_game(run_state, game, action_id, policy)
	if stake <= 0 or stake > run_state.bankroll:
		return ""
	var rng := run_state.create_rng()
	var ui_state := _prepared_metrics_ui_state(game, run_state, game_id, action_id, stake, policy)
	var result := game.resolve_with_context(action_id, stake, run_state, run_state.current_environment, rng, ui_state)
	if not bool(result.get("ok", false)):
		return ""
	if bool(result.get("host_apply_result", false)):
		GameModule.apply_result(run_state, result, rng)
	else:
		run_state.save_rng(rng)
	if not bool(result.get("slot_runtime_tick", false)):
		run_state.advance_environment_turns(1)
	run["game_actions"] = int(run.get("game_actions", 0)) + 1
	var action_kind := str(result.get("action_kind", ""))
	if action_kind in ["cheat", "risky", "advantage"]:
		run["cheat_actions"] = int(run.get("cheat_actions", 0)) + 1
	else:
		run["legal_actions"] = int(run.get("legal_actions", 0)) + 1
	var mix := _dict(run.get("game_mix", {}))
	mix[game_id] = int(mix.get(game_id, 0)) + 1
	run["game_mix"] = mix
	_count_action(run, "game")
	return label


func _numbers_boundary(run_state: RunState, run: Dictionary) -> String:
	var state := _dict(run.get("style_state", {}))
	var phase := str(state.get("numbers_phase", "runner"))
	if phase == "runner":
		var runner_label := _numbers_runner_boundary(run_state, run)
		if not runner_label.is_empty():
			return runner_label
		if not bool(run_state.narrative_flags.get("numbers_route_paid", false)) and not bool(run_state.narrative_flags.get("numbers_route_failed", false)):
			return ""
		state = _dict(run.get("style_state", {}))
		state["numbers_phase"] = "rank_lucky"
		run["style_state"] = state
		return _numbers_boundary(run_state, run)
	if phase == "rank_lucky":
		var label := _crew_job_boundary(run_state, run, "crew_lucky", "made", false)
		if label.is_empty() and _crew_at_least_rank(run_state, "crew_lucky", "made"):
			state = _dict(run.get("style_state", {}))
			state["numbers_phase"] = "rank_mags"
			run["style_state"] = state
			return _numbers_boundary(run_state, run)
		return label
	if phase == "rank_mags":
		var label := _crew_job_boundary(run_state, run, "crew_mags", "made", false)
		if label.is_empty() and _crew_at_least_rank(run_state, "crew_mags", "made"):
			state = _dict(run.get("style_state", {}))
			state["numbers_phase"] = "operate"
			run["style_state"] = state
			return _numbers_boundary(run_state, run)
		return label
	return _numbers_fix_boundary(run_state, run)


func _numbers_runner_boundary(run_state: RunState, run: Dictionary) -> String:
	if run_state.delivery_has_active_run():
		return _drive_active_delivery_boundary(run_state, run, "numbers_runner")
	if not _crew_at_least_rank(run_state, "crew_lucky", "associate"):
		return _crew_job_boundary(run_state, run, "crew_lucky", "associate", false)
	if str(run_state.current_environment.get("archetype_id", "")) != "small_underground_casino":
		return _travel_to_node_boundary(run_state, run, _world_node_for_archetype(run_state, "small_underground_casino"), false, "numbers_runner_desk_travel")
	if not bool(run_state.numbers_desk_status().get("runner_available", false)):
		run_state.advance_environment_turns(1)
		_count_action(run, "hook")
		return "numbers_runner_wait"
	var begun := run_state.numbers_begin_collection_route()
	if not bool(begun.get("ok", false)):
		return ""
	run_state.advance_environment_turns(1)
	_count_action(run, "hook")
	return "numbers_runner_begin"


func _numbers_fix_boundary(run_state: RunState, run: Dictionary) -> String:
	if run_state.delivery_has_active_run():
		return _drive_active_delivery_boundary(run_state, run, "numbers_fix_bribe")
	var desk := run_state.numbers_desk_status()
	var stage := str(desk.get("fix_stage", "locked"))
	if stage in ["ready", "camouflage"] and str(run_state.current_environment.get("archetype_id", "")) != "small_underground_casino":
		var desk_node_id := _world_node_for_archetype(run_state, "small_underground_casino")
		return _travel_to_node_boundary(run_state, run, desk_node_id, false, "numbers_desk_travel")
	if stage == "ready":
		if run_state.bankroll < 60:
			return ""
		var begun := run_state.numbers_begin_fix_bribe()
		if not bool(begun.get("ok", false)):
			return ""
		run_state.advance_environment_turns(1)
		_count_action(run, "hook")
		return "numbers_fix_bribe_begin"
	if stage == "camouflage":
		if run_state.bankroll < 60:
			return ""
		var allocated := run_state.numbers_fix_allocate({
			"small_underground_casino": 18,
			"bar": 16,
			"motel": 14,
			"gas_station_casino": 12,
		})
		if not bool(allocated.get("ok", false)):
			return ""
		run_state.advance_environment_turns(1)
		_count_action(run, "hook")
		return "numbers_fix_allocate"
	if stage == "payday":
		var slip_label := _buy_numbers_slip_boundary(run_state, run, "numbers_payday_clock")
		if not slip_label.is_empty():
			return slip_label
		run_state.advance_environment_turns(1)
		_count_action(run, "hook")
		return "numbers_payday_clock"
	return ""


func _buy_numbers_slip_boundary(run_state: RunState, run: Dictionary, label: String) -> String:
	if run_state.bankroll < 4:
		return ""
	var status := run_state.numbers_status()
	var venue_id := str(run_state.current_environment.get("archetype_id", ""))
	var venue_open := false
	for venue_value in _array(status.get("venue_status", [])):
		var venue := _dict(venue_value)
		if str(venue.get("id", "")) == venue_id:
			venue_open = bool(venue.get("open", false))
			break
	if not venue_open:
		return ""
	var digits := "%03d" % posmod(_stable_hash(run_state.seed_text + ":numbers:" + str(run.get("actions", 0))), 1000)
	var bought := run_state.numbers_buy_slip(digits, 4, "straight")
	if not bool(bought.get("ok", false)):
		return ""
	run_state.advance_environment_turns(1)
	run["game_actions"] = int(run.get("game_actions", 0)) + 1
	run["legal_actions"] = int(run.get("legal_actions", 0)) + 1
	var mix := _dict(run.get("game_mix", {}))
	mix["the_numbers"] = int(mix.get("the_numbers", 0)) + 1
	run["game_mix"] = mix
	_count_action(run, "game")
	return label


func _prepare_pusher(run_state: RunState, run: Dictionary) -> void:
	var state := _dict(run.get("style_state", {}))
	state["pusher_phase"] = "seek_natural_machine"
	state["surface_time_msec"] = 0
	state["drops"] = 0
	run["style_state"] = state


func _pusher_boundary(run_state: RunState, run: Dictionary) -> String:
	var game: GameModule = game_modules.get("coin_pusher", null)
	if game == null:
		return ""
	var state := _dict(run.get("style_state", {}))
	var phase := str(state.get("pusher_phase", "seek_natural_machine"))
	if phase == "seek_natural_machine":
		var gas_node_id := _world_node_for_archetype(run_state, "gas_station_casino")
		if run_state.current_world_node_id() != gas_node_id:
			return _travel_to_node_boundary(run_state, run, gas_node_id, false, "coin_pusher_seek_travel")
		if not _string_array(run_state.current_environment.get("game_ids", [])).has("coin_pusher"):
			state["pusher_phase"] = "natural_machine_unavailable"
			run["style_state"] = state
			return ""
		game.enter(run_state, run_state.current_environment)
		var surface := game.surface_state(run_state, run_state.current_environment, {})
		state["pusher_phase"] = "grind"
		state["pusher_variation"] = str(surface.get("coin_pusher_variation_id", "quarter_falls"))
		run["style_state"] = state
		run["pusher_machine_reached"] = true
		run["pusher_variation"] = str(state.get("pusher_variation", "quarter_falls"))
		return _pusher_boundary(run_state, run)
	# Keep one travel/debt dollar in reserve instead of intentionally triggering
	# the global bankroll-zero terminal before a physical tray can be collected.
	if phase == "natural_machine_unavailable" or run_state.bankroll <= 1:
		return ""
	var rng := run_state.create_rng("balance06_pusher_drop")
	var result := game.resolve_with_context("drop_quarter", 1, run_state, run_state.current_environment, rng, {})
	if not bool(result.get("ok", false)):
		return ""
	if bool(result.get("host_apply_result", false)):
		GameModule.apply_result(run_state, result, rng)
	else:
		run_state.save_rng(rng)
	var surface_time := int(state.get("surface_time_msec", 0))
	for _tick in range(20):
		surface_time += 17
		game.surface_realtime_state_patch(run_state, run_state.current_environment, {"surface_time_msec": surface_time}, {})
	state["surface_time_msec"] = surface_time
	state["drops"] = int(state.get("drops", 0)) + 1
	# The tray is economically inert until COLLECT. Use that real boundary after
	# every fixed-tick drop so an arbitrary action cap cannot strand claimable
	# cash in the presentation tray and understate the grinder's bankroll.
	game.surface_action_command("coin_pusher_collect", 0, false, {}, run_state, run_state.current_environment)
	run["style_state"] = state
	run_state.advance_environment_turns(1)
	run["game_actions"] = int(run.get("game_actions", 0)) + 1
	run["legal_actions"] = int(run.get("legal_actions", 0)) + 1
	var mix := _dict(run.get("game_mix", {}))
	mix["coin_pusher"] = int(mix.get("coin_pusher", 0)) + 1
	run["game_mix"] = mix
	_count_action(run, "game")
	return "coin_pusher_drop"


func _heist_boundary(run_state: RunState, run: Dictionary) -> String:
	var state := _dict(run.get("style_state", {}))
	var phase := str(state.get("heist_phase", "rank"))
	if phase == "rank":
		var label := _crew_job_boundary(run_state, run, "crew_bishop", "inner_circle", false)
		if not label.is_empty():
			return label
		if not _crew_at_least_rank(run_state, "crew_bishop", "inner_circle"):
			return ""
		state = _dict(run.get("style_state", {}))
		state["heist_phase"] = "lock"
		run["style_state"] = state
		return _heist_boundary(run_state, run)
	if phase == "lock":
		var hooks := _dict(run_state.current_environment.get("scenario_hook_flags", {}))
		hooks["audit_night"] = true
		run_state.current_environment["scenario_hook_flags"] = hooks
		run_state.store_current_world_node_environment()
		var locked := run_state.crew_heist_lock("the_count")
		if not bool(locked.get("ok", false)):
			failures.append("Heist rusher could not lock The Count for seed %s: %s" % [run_state.seed_text, str(locked.get("message", ""))])
			return ""
		state["heist_phase"] = "identity_travel"
		state["identity_sessions_seen"] = 0
		run["style_state"] = state
		run_state.advance_environment_turns(1)
		_count_action(run, "hook")
		return "heist_lock"
	if phase == "identity_travel":
		var identity_grand_node_id := _world_node_for_archetype(run_state, GRAND_CASINO_ID)
		if run_state.current_world_node_id() != identity_grand_node_id:
			return _travel_to_node_boundary(run_state, run, identity_grand_node_id, false, "heist_identity_travel")
		state["heist_phase"] = "identity"
		run["style_state"] = state
		return _heist_boundary(run_state, run)
	if phase == "identity":
		var heist_state := _dict(run_state.crew_heist_state)
		var setup := _dict(heist_state.get("setup", {}))
		var session := int(setup.get("identity_sessions", 0))
		var sessions_seen := int(state.get("identity_sessions_seen", 0))
		if bool(setup.get("identity", false)) or session >= 3:
			state["heist_phase"] = "schedule"
			run["style_state"] = state
			return _heist_boundary(run_state, run)
		if session > sessions_seen:
			state["identity_sessions_seen"] = session
			state["heist_phase"] = "identity_reset"
			run["style_state"] = state
			return _heist_boundary(run_state, run)
		var bet := 8 + posmod(_stable_hash(run_state.seed_text + ":identity:" + str(session)), 23)
		var identity_label := _play_specific_game_boundary(run_state, run, "blackjack", "clean", bet, "heist_identity_session")
		if identity_label.is_empty():
			return ""
		var post_setup := _dict(_dict(run_state.crew_heist_state).get("setup", {}))
		var post_session := int(post_setup.get("identity_sessions", session))
		state = _dict(run.get("style_state", {}))
		state["identity_sessions_seen"] = maxi(sessions_seen, post_session)
		state["heist_phase"] = "schedule" if bool(post_setup.get("identity", false)) or post_session >= 3 else "identity_reset"
		run["style_state"] = state
		return identity_label
	if phase == "identity_reset":
		var reset_target := _world_node_for_archetype(run_state, "bar")
		if reset_target.is_empty():
			reset_target = _world_node_for_archetype(run_state, "motel")
		var reset_label := _travel_to_node_boundary(run_state, run, reset_target, false, "heist_identity_reset")
		if run_state.current_world_node_id() == reset_target:
			state["heist_phase"] = "identity_travel"
			run["style_state"] = state
		return reset_label
	if phase == "schedule":
		var count_state := _dict(run_state.crew_heist_state)
		if bool(_dict(count_state.get("setup", {})).get("schedule", false)):
			state["heist_phase"] = "swap_cart"
			run["style_state"] = state
			return _heist_boundary(run_state, run)
		if run_state.delivery_has_active_run():
			return _drive_active_delivery_boundary(run_state, run, "heist_schedule")
		var schedule := run_state.crew_heist_begin_count_schedule()
		if not bool(schedule.get("ok", false)):
			failures.append("Heist rusher could not begin Count schedule for seed %s: %s" % [run_state.seed_text, str(schedule.get("message", ""))])
			return ""
		run_state.advance_environment_turns(1)
		_count_action(run, "hook")
		return "heist_schedule_begin"
	if phase == "swap_cart":
		var count_state := _dict(run_state.crew_heist_state)
		if bool(_dict(count_state.get("setup", {})).get("swap_cart", false)):
			state["heist_phase"] = "begin_play"
			run["style_state"] = state
			return _heist_boundary(run_state, run)
		if run_state.delivery_has_active_run():
			return _drive_active_delivery_boundary(run_state, run, "heist_swap_cart")
		var cart := run_state.crew_heist_begin_count_swap_cart()
		if not bool(cart.get("ok", false)):
			failures.append("Heist rusher could not begin Count cart for seed %s: %s" % [run_state.seed_text, str(cart.get("message", ""))])
			return ""
		run_state.advance_environment_turns(1)
		_count_action(run, "hook")
		return "heist_swap_cart_begin"
	if phase == "begin_play":
		var begin_play_grand_node_id := _world_node_for_archetype(run_state, GRAND_CASINO_ID)
		if run_state.current_world_node_id() != begin_play_grand_node_id:
			return _travel_to_node_boundary(run_state, run, begin_play_grand_node_id, false, "heist_live_table_travel")
		var begun := run_state.crew_heist_begin_play()
		if not bool(begun.get("ok", false)):
			failures.append("Heist rusher could not begin The Count for seed %s: %s" % [run_state.seed_text, str(begun.get("message", ""))])
			return ""
		state["heist_phase"] = "play"
		run["style_state"] = state
		run_state.advance_environment_turns(1)
		_count_action(run, "hook")
		return "heist_begin_play"
	if phase == "play":
		var play_grand_node_id := _world_node_for_archetype(run_state, GRAND_CASINO_ID)
		if run_state.current_world_node_id() != play_grand_node_id:
			return _travel_to_node_boundary(run_state, run, play_grand_node_id, false, "heist_live_table_travel")
		var count_state := _dict(run_state.crew_heist_state)
		var round_index := int(_dict(count_state.get("play", {})).get("round", 0))
		if round_index >= 3:
			state["heist_phase"] = "getaway"
			run["style_state"] = state
			return _heist_boundary(run_state, run)
		var decision_ids := ["go", "distraction", "exit"]
		var decisions := ["hold", "sit", "dock"]
		if round_index < decision_ids.size():
			run_state.crew_heist_decide(str(decision_ids[round_index]), str(decisions[round_index]))
		var bet := 8 + posmod(_stable_hash(run_state.seed_text + ":heist_bet:" + str(round_index)), 23)
		return _play_specific_game_boundary(run_state, run, "blackjack", "clean", bet, "heist_live_round")
	if phase == "getaway":
		if not run_state.delivery_has_active_run():
			var getaway := run_state.crew_heist_begin_getaway()
			if not bool(getaway.get("ok", false)):
				failures.append("Heist rusher getaway failed for seed %s: %s" % [run_state.seed_text, str(getaway.get("message", ""))])
				return ""
			run_state.advance_environment_turns(1)
			_count_action(run, "hook")
			return "heist_getaway_begin"
		var getaway_label := _drive_active_delivery_boundary(run_state, run, "heist_getaway")
		if run_state.is_terminal():
			run["victory_action"] = int(run.get("actions", 0))
		return getaway_label
	return ""


func _record_economy_boundary(run: Dictionary, run_state: RunState, label: String, before_bankroll: int, before_heat: int, before_debt: int) -> void:
	var bankroll_delta := run_state.bankroll - before_bankroll
	var heat_delta := run_state.suspicion_level() - before_heat
	var debt_delta := _total_debt_balance(run_state) - before_debt
	var entry := {
		"action": int(run.get("actions", 0)),
		"label": label,
		"bankroll_delta": bankroll_delta,
		"heat_delta": heat_delta,
		"debt_delta": debt_delta,
		"bankroll": run_state.bankroll,
		"heat": run_state.suspicion_level(),
		"debt": _total_debt_balance(run_state),
	}
	var ledger := _array(run.get("ledger", []))
	ledger.append(entry)
	run["ledger"] = ledger
	if bankroll_delta > 0:
		var sources := _dict(run.get("source_totals", {}))
		sources[label] = int(sources.get(label, 0)) + bankroll_delta
		run["source_totals"] = sources
	elif bankroll_delta < 0:
		var sinks := _dict(run.get("sink_totals", {}))
		sinks[label] = int(sinks.get(label, 0)) - bankroll_delta
		run["sink_totals"] = sinks
	run["peak_bankroll"] = maxi(int(run.get("peak_bankroll", run_state.bankroll)), run_state.bankroll)
	run["minimum_bankroll"] = mini(int(run.get("minimum_bankroll", run_state.bankroll)), run_state.bankroll)
	run["peak_heat"] = maxi(int(run.get("peak_heat", 0)), run_state.suspicion_level())
	run["peak_debt"] = maxi(int(run.get("peak_debt", 0)), _total_debt_balance(run_state))


func _record_thresholds(run: Dictionary, run_state: RunState) -> void:
	var action := int(run.get("actions", 0))
	var debt := _total_debt_balance(run_state)
	var debt_actions := _dict(run.get("first_debt_action", {}))
	for threshold in DEBT_THRESHOLDS:
		var key := str(threshold)
		if debt >= int(threshold) and not debt_actions.has(key):
			debt_actions[key] = action
	run["first_debt_action"] = debt_actions
	var bankroll_actions := _dict(run.get("first_bankroll_action", {}))
	for threshold in [75, 50, 25, 0]:
		var key := str(threshold)
		if run_state.bankroll <= threshold and not bankroll_actions.has(key):
			bankroll_actions[key] = action
	run["first_bankroll_action"] = bankroll_actions
	if run_state.suspicion_level() >= 50 and int(run.get("first_heat_50_action", -1)) < 0:
		run["first_heat_50_action"] = action
	if run_state.suspicion_level() >= 80 and int(run.get("first_heat_80_action", -1)) < 0:
		run["first_heat_80_action"] = action


func _is_pressure_terminal(run: Dictionary) -> bool:
	return str(run.get("failure_reason", "")) in [RunState.FAILURE_BANKROLL_ZERO, RunState.FAILURE_STRANDED, RunState.FAILURE_POLICE_CAPTURE, RunState.FAILURE_CASINO_TAKEN_OUT_BACK]


func _audit_aggregate(runs: Array, max_actions: int) -> Dictionary:
	var rows: Array = []
	for style_value in PLAYSTYLES:
		var style_id := str(_dict(style_value).get("id", ""))
		var selected := _filter_runs(runs, "playstyle", style_id)
		if selected.is_empty():
			continue
		var observed_terminals := _uncensored_runs(selected)
		var pusher_reached := _bool_runs(selected, "pusher_machine_reached")
		rows.append({
			"playstyle": style_id,
			"run_count": selected.size(),
			"final_bankroll": _distribution(selected, "final_bankroll"),
			"peak_bankroll": _distribution(selected, "peak_bankroll"),
			"minimum_bankroll": _distribution(selected, "minimum_bankroll"),
			"actions": _distribution(selected, "actions"),
			"final_heat": _distribution(selected, "final_heat"),
			"peak_heat": _distribution(selected, "peak_heat"),
			"final_debt": _distribution(selected, "debt_balance"),
			"peak_debt": _distribution(selected, "peak_debt"),
			"route_cost_total": _distribution(selected, "route_cost_total"),
			"game_actions": _distribution(selected, "game_actions"),
			"travel_count": _distribution(selected, "travel_count"),
			"victory_action": _distribution_nonnegative(selected, "victory_action"),
			"victory_action_by_route": _grouped_nonnegative_distribution(selected, "victory_route", "victory_action"),
			"victory_rate": _rate(_won_count(selected), selected.size()),
			"conditioned_probe_rate": _rate(_bool_count(selected, "conditioned_probe"), selected.size()),
			"pusher_machine_reached_rate": _rate(pusher_reached.size(), selected.size()),
			"pusher_variation_counts": _value_counts(pusher_reached, "pusher_variation"),
			"pusher_reached_final_bankroll": _distribution(pusher_reached, "final_bankroll"),
			"pusher_reached_final_bankroll_by_variation": _grouped_nonnegative_distribution(pusher_reached, "pusher_variation", "final_bankroll"),
			"pusher_reached_actions": _distribution(pusher_reached, "actions"),
			"terminal_observation_rate": _rate(observed_terminals.size(), selected.size()),
			"censored_action_cap_rate": _rate(_bool_count(selected, "censored"), selected.size()),
			"pressure_terminal_rate_observed_terminals": _rate(_bool_count(observed_terminals, "pressure_terminal"), observed_terminals.size()),
			"choice_terminal_rate_observed_terminals": _rate(_bool_count(observed_terminals, "choice_terminal"), observed_terminals.size()),
			"pressure_terminal_share_all_runs": _rate(_bool_count(selected, "pressure_terminal"), selected.size()),
			"choice_terminal_share_all_runs": _rate(_bool_count(selected, "choice_terminal"), selected.size()),
			"failure_causes_observed_terminals": _value_counts(observed_terminals, "failure_reason"),
			"victory_routes": _value_counts(selected, "victory_route"),
			"debt_threshold_actions": _threshold_distributions(selected),
			"bankroll_threshold_actions": _bankroll_threshold_distributions(selected),
			"source_totals": _map_value_distributions(selected, "source_totals"),
			"sink_totals": _map_value_distributions(selected, "sink_totals"),
			"game_mix": _map_value_distributions(selected, "game_mix"),
			"game_action_share": _map_share_distributions(selected, "game_mix", "game_actions"),
			"bankroll_curve": _curve_distribution(selected, max_actions),
		})
	return {"playstyles": rows}


func _distribution(runs: Array, key: String) -> Dictionary:
	var values: Array = []
	for run_value in runs:
		if typeof(run_value) == TYPE_DICTIONARY:
			values.append(float((run_value as Dictionary).get(key, 0)))
	return _distribution_values(values)


func _distribution_nonnegative(runs: Array, key: String) -> Dictionary:
	var values: Array = []
	for run_value in runs:
		if typeof(run_value) != TYPE_DICTIONARY:
			continue
		var value := float((run_value as Dictionary).get(key, -1))
		if value >= 0:
			values.append(value)
	return _distribution_values(values)


func _grouped_nonnegative_distribution(runs: Array, group_key: String, value_key: String) -> Dictionary:
	var grouped := {}
	for run_value in runs:
		if typeof(run_value) != TYPE_DICTIONARY:
			continue
		var run: Dictionary = run_value
		var group := str(run.get(group_key, "")).strip_edges()
		var value := float(run.get(value_key, -1))
		if group.is_empty() or value < 0:
			continue
		var values := _array(grouped.get(group, []))
		values.append(value)
		grouped[group] = values
	var result := {}
	for group_value in grouped.keys():
		result[str(group_value)] = _distribution_values(_array(grouped.get(group_value, [])))
	return result


func _distribution_values(values: Array) -> Dictionary:
	if values.is_empty():
		return {"n": 0}
	values.sort()
	var total := 0.0
	for value in values:
		total += float(value)
	var mean := total / float(values.size())
	var squared := 0.0
	for value in values:
		squared += pow(float(value) - mean, 2.0)
	return {
		"n": values.size(),
		"min": float(values[0]),
		"p05": _percentile(values, 0.05),
		"p25": _percentile(values, 0.25),
		"median": _percentile(values, 0.50),
		"p75": _percentile(values, 0.75),
		"p95": _percentile(values, 0.95),
		"max": float(values[-1]),
		"mean": mean,
		"sample_standard_deviation": sqrt(squared / float(maxi(1, values.size() - 1))),
	}


func _percentile(sorted_values: Array, fraction: float) -> float:
	if sorted_values.size() == 1:
		return float(sorted_values[0])
	var position := clampf(fraction, 0.0, 1.0) * float(sorted_values.size() - 1)
	var low := int(floor(position))
	var high := int(ceil(position))
	var weight := position - float(low)
	return lerpf(float(sorted_values[low]), float(sorted_values[high]), weight)


func _bool_count(runs: Array, key: String) -> int:
	var count := 0
	for run_value in runs:
		if typeof(run_value) == TYPE_DICTIONARY and bool((run_value as Dictionary).get(key, false)):
			count += 1
	return count


func _uncensored_runs(runs: Array) -> Array:
	var result: Array = []
	for run_value in runs:
		if typeof(run_value) == TYPE_DICTIONARY and not bool((run_value as Dictionary).get("censored", false)):
			result.append(run_value)
	return result


func _bool_runs(runs: Array, key: String) -> Array:
	var result: Array = []
	for run_value in runs:
		if typeof(run_value) == TYPE_DICTIONARY and bool((run_value as Dictionary).get(key, false)):
			result.append(run_value)
	return result


func _value_counts(runs: Array, key: String) -> Dictionary:
	var counts := {}
	for run_value in runs:
		if typeof(run_value) != TYPE_DICTIONARY:
			continue
		var value := str((run_value as Dictionary).get(key, ""))
		if value.is_empty():
			value = "none"
		counts[value] = int(counts.get(value, 0)) + 1
	return counts


func _threshold_distributions(runs: Array) -> Dictionary:
	var result := {}
	for threshold in DEBT_THRESHOLDS:
		var values: Array = []
		for run_value in runs:
			if typeof(run_value) != TYPE_DICTIONARY:
				continue
			var row := _dict((run_value as Dictionary).get("first_debt_action", {}))
			if row.has(str(threshold)):
				values.append(float(row[str(threshold)]))
		result[str(threshold)] = _distribution_values(values)
	return result


func _bankroll_threshold_distributions(runs: Array) -> Dictionary:
	var result := {}
	for threshold in [75, 50, 25, 0]:
		var values: Array = []
		for run_value in runs:
			if typeof(run_value) != TYPE_DICTIONARY:
				continue
			var row := _dict((run_value as Dictionary).get("first_bankroll_action", {}))
			if row.has(str(threshold)):
				values.append(float(row[str(threshold)]))
		result[str(threshold)] = _distribution_values(values)
	return result


func _map_value_distributions(runs: Array, key: String) -> Dictionary:
	var all_keys: Array = []
	for run_value in runs:
		if typeof(run_value) != TYPE_DICTIONARY:
			continue
		for value_key in _dict((run_value as Dictionary).get(key, {})).keys():
			var text_key := str(value_key)
			if not all_keys.has(text_key):
				all_keys.append(text_key)
	all_keys.sort()
	var result := {}
	for value_key in all_keys:
		var values: Array = []
		for run_value in runs:
			if typeof(run_value) == TYPE_DICTIONARY:
				values.append(float(_dict((run_value as Dictionary).get(key, {})).get(value_key, 0)))
		result[value_key] = _distribution_values(values)
	return result


func _map_share_distributions(runs: Array, map_key: String, denominator_key: String) -> Dictionary:
	var all_keys: Array = []
	for run_value in runs:
		if typeof(run_value) != TYPE_DICTIONARY:
			continue
		for value_key in _dict((run_value as Dictionary).get(map_key, {})).keys():
			var text_key := str(value_key)
			if not all_keys.has(text_key):
				all_keys.append(text_key)
	all_keys.sort()
	var result := {}
	for value_key in all_keys:
		var values: Array = []
		for run_value in runs:
			if typeof(run_value) != TYPE_DICTIONARY:
				continue
			var run: Dictionary = run_value
			var denominator := maxi(0, int(run.get(denominator_key, 0)))
			if denominator > 0:
				values.append(float(_dict(run.get(map_key, {})).get(value_key, 0)) / float(denominator))
		result[value_key] = _distribution_values(values)
	return result


func _curve_distribution(runs: Array, max_actions: int) -> Array:
	var rows: Array = []
	for action in range(0, max_actions + 1, 8):
		var bankrolls: Array = []
		var heats: Array = []
		var debts: Array = []
		for run_value in runs:
			if typeof(run_value) != TYPE_DICTIONARY:
				continue
			var curve := _array((run_value as Dictionary).get("curve", []))
			if curve.is_empty():
				continue
			var index := mini(action, curve.size() - 1)
			var point := _dict(curve[index])
			bankrolls.append(float(point.get("bankroll", 0)))
			heats.append(float(point.get("heat", 0)))
			debts.append(float(point.get("debt_balance", 0)))
		rows.append({"action": action, "bankroll": _distribution_values(bankrolls), "heat": _distribution_values(heats), "debt": _distribution_values(debts)})
	return rows


func _write_audit_json(path: String, report: Dictionary) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write audit report: %s" % absolute)
		return false
	file.store_string(JSON.stringify(report, "\t", false) + "\n")
	file.close()
	return true
