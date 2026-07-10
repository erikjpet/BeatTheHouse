extends SceneTree

# Headless audit for environment generation and travel-only run paths.

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const WorldMapScript := preload("res://scripts/core/world_map.gd")

const DEFAULT_RUN_COUNT := 100
const DEFAULT_VISITS_PER_RUN := 6
const DEFAULT_OUTPUT_JSON := "res://.tmp/environment_generation_audit/report.json"
const DEFAULT_OUTPUT_MARKDOWN := "res://.tmp/environment_generation_audit/report.md"

var library: ContentLibrary
var generator: RunGenerator
var records: Array = []
var travel_records: Array = []
var run_summaries: Array = []
var failures: Array = []
var warnings: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var options := _parse_options()
	var run_count := maxi(1, int(options.get("runs", DEFAULT_RUN_COUNT)))
	var visits_per_run := maxi(1, int(options.get("visits", DEFAULT_VISITS_PER_RUN)))
	var output_json := str(options.get("output_json", DEFAULT_OUTPUT_JSON))
	var output_markdown := str(options.get("output_markdown", DEFAULT_OUTPUT_MARKDOWN))
	var seed_prefix := str(options.get("seed_prefix", "")).strip_edges()
	if seed_prefix.is_empty():
		seed_prefix = _random_seed_prefix()

	library = ContentLibraryScript.new()
	library.load()
	for error in library.validation_errors:
		failures.append("Content library validation error: %s" % error)
	for warning in library.validation_warnings:
		warnings.append("Content library validation warning: %s" % warning)
	generator = RunGeneratorScript.new(library)

	var entropy := RandomNumberGenerator.new()
	entropy.randomize()
	var used_seeds := {}
	for run_index in range(run_count):
		var seed := _unique_seed(seed_prefix, run_index, entropy, used_seeds)
		_simulate_run(run_index, seed, visits_per_run)

	var aggregate := _build_aggregate(run_count, visits_per_run, seed_prefix)
	var report := {
		"tool": "environment_generation_audit",
		"generated_at_unix": Time.get_unix_time_from_system(),
		"run_count": run_count,
		"visits_per_run_target": visits_per_run,
		"seed_prefix": seed_prefix,
		"passed": failures.is_empty(),
		"failure_count": failures.size(),
		"warning_count": warnings.size(),
		"method": _method_notes(),
		"aggregate": aggregate,
		"runs": run_summaries,
		"environment_records": records,
		"travel_records": travel_records,
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
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--runs="):
			options["runs"] = maxi(1, int(text.trim_prefix("--runs=")))
		elif text.begins_with("--visits="):
			options["visits"] = maxi(1, int(text.trim_prefix("--visits=")))
		elif text.begins_with("--output="):
			options["output_json"] = text.trim_prefix("--output=")
		elif text.begins_with("--report="):
			options["output_markdown"] = text.trim_prefix("--report=")
		elif text.begins_with("--seed-prefix="):
			options["seed_prefix"] = text.trim_prefix("--seed-prefix=")
	return options


func _random_seed_prefix() -> String:
	var entropy := RandomNumberGenerator.new()
	entropy.randomize()
	return "ENV-AUDIT-%d-%d-%d" % [
		int(Time.get_unix_time_from_system()),
		int(Time.get_ticks_usec()),
		int(entropy.randi()),
	]


func _unique_seed(prefix: String, run_index: int, entropy: RandomNumberGenerator, used_seeds: Dictionary) -> String:
	var seed := "%s-%03d-%d" % [prefix, run_index, int(entropy.randi())]
	while used_seeds.has(seed):
		seed = "%s-%03d-%d" % [prefix, run_index, int(entropy.randi())]
	used_seeds[seed] = true
	return seed


func _simulate_run(run_index: int, seed: String, visits_per_run: int) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed)
	var path_rng := run_state.create_rng("environment_generation_audit_path")
	generator.next_environment(run_state)
	_audit_world_map_beach_delta(run_state.world_map, seed)

	var run_summary := {
		"run_index": run_index,
		"seed": seed,
		"visited": [],
		"stopped_reason": "completed",
		"start_bankroll": run_state.bankroll,
		"end_bankroll": run_state.bankroll,
		"end_suspicion": run_state.suspicion_level(),
		"events_resolved": 0,
		"travel_count": 0,
		"travel_lock_wait_actions": 0,
	}

	for visit_index in range(visits_per_run):
		if run_state.current_environment.is_empty():
			run_summary["stopped_reason"] = "missing_environment"
			break
		var record := _record_environment(run_state, run_index, seed, visit_index)
		_audit_environment_unique_object_classes(run_state.current_environment, seed, visit_index)
		var event_results := _resolve_travel_unlock_events(run_state, path_rng)
		record["events_resolved_for_travel"] = event_results
		record["resolved_event_ids_after_policy"] = _copy_array(run_state.current_environment.get("resolved_event_ids", []))
		record["next_archetypes_after_events"] = _copy_array(run_state.current_environment.get("next_archetypes", []))
		record["travel_after_events"] = _travel_choices(run_state, true)
		record["bankroll_after_events"] = run_state.bankroll
		record["suspicion_after_events"] = run_state.suspicion_level()
		records.append(record)
		var visited: Array = run_summary.get("visited", [])
		visited.append({
			"visit_index": visit_index,
			"environment_id": str(run_state.current_environment.get("id", "")),
			"archetype_id": str(run_state.current_environment.get("archetype_id", "")),
			"kind": str(run_state.current_environment.get("kind", "")),
			"games": _copy_array(run_state.current_environment.get("game_ids", [])),
			"events": _copy_array(run_state.current_environment.get("event_ids", [])),
			"items": _item_ids_from_offers(run_state.current_environment.get("item_offers", [])),
		})
		run_summary["visited"] = visited
		run_summary["events_resolved"] = int(run_summary.get("events_resolved", 0)) + event_results.size()

		if visit_index >= visits_per_run - 1:
			break
		var choice := _pick_travel_choice(run_state, path_rng)
		if choice.is_empty():
			var wait_actions := _current_travel_lock_remaining(run_state)
			if wait_actions > 0:
				run_state.advance_environment_turns(wait_actions)
				run_summary["travel_lock_wait_actions"] = int(run_summary.get("travel_lock_wait_actions", 0)) + wait_actions
				choice = _pick_travel_choice(run_state, path_rng)
		if choice.is_empty():
			run_summary["stopped_reason"] = "no_enabled_travel"
			break
		var travel_record := _travel_to(run_state, choice)
		travel_record["run_index"] = run_index
		travel_record["seed"] = seed
		travel_record["from_visit_index"] = visit_index
		travel_records.append(travel_record)
		run_summary["travel_count"] = int(run_summary.get("travel_count", 0)) + 1
		if run_state.is_terminal():
			run_summary["stopped_reason"] = str(run_state.run_failure_reason)
			break

	run_summary["end_bankroll"] = run_state.bankroll
	run_summary["end_suspicion"] = run_state.suspicion_level()
	run_summary["environment_count"] = (run_summary.get("visited", []) as Array).size()
	run_summaries.append(run_summary)


func _record_environment(run_state: RunState, run_index: int, seed: String, visit_index: int) -> Dictionary:
	var environment := run_state.current_environment.duplicate(true)
	var game_ids := _string_array(environment.get("game_ids", []))
	var game_states := _copy_dict(environment.get("game_states", {}))
	var state_summaries := {}
	for game_id in game_ids:
		var state := _copy_dict(game_states.get(game_id, {}))
		state_summaries[game_id] = _summarize_game_state(game_id, state)
	return {
		"run_index": run_index,
		"seed": seed,
		"visit_index": visit_index,
		"environment_id": str(environment.get("id", "")),
		"archetype_id": str(environment.get("archetype_id", "")),
		"display_name": str(environment.get("display_name", "")),
		"kind": str(environment.get("kind", "")),
		"tier": int(environment.get("tier", 1)),
		"depth": int(environment.get("depth", visit_index)),
		"mood": str(environment.get("mood", "")),
		"art_key": str(environment.get("art_key", "")),
		"visual_context": _copy_dict(environment.get("visual_context", {})),
		"security_profile": _copy_dict(environment.get("security_profile", {})),
		"economic_profile": _copy_dict(environment.get("economic_profile", {})),
		"local_narrative_flags": _copy_dict(environment.get("local_narrative_flags", {})),
		"suspicion_cues": _copy_array(environment.get("suspicion_cues", [])),
		"games": game_ids,
		"game_state_summaries": state_summaries,
		"events": _string_array(environment.get("event_ids", [])),
		"event_trigger_status": _event_trigger_status(run_state),
		"items": _item_offer_records(environment.get("item_offers", [])),
		"services": _string_array(environment.get("service_ids", [])),
		"lenders": _string_array(environment.get("lender_hooks", [])),
		"next_archetypes_initial": _string_array(environment.get("next_archetypes", [])),
		"travel_hooks_initial": _string_array(environment.get("travel_hooks", [])),
		"travel_initial": _travel_choices(run_state, true),
		"travel_lock_remaining": int(environment.get("travel_lock_remaining", 0)),
		"turns": int(environment.get("turns", 0)),
		"bankroll_on_entry": run_state.bankroll,
		"suspicion_on_entry": run_state.suspicion_level(),
	}


func _audit_world_map_beach_delta(map_data: Dictionary, seed: String) -> void:
	if map_data.is_empty():
		return
	var beach := WorldMapScript.node_by_id(map_data, "beach")
	var delta := WorldMapScript.node_by_id(map_data, "delta_queen")
	if beach.is_empty() or delta.is_empty():
		failures.append("%s: generated world map is missing beach or delta_queen." % seed)
		return
	var edge := _world_map_edge_between(map_data, "beach", "delta_queen")
	if edge.is_empty():
		failures.append("%s: beach must have a direct edge to delta_queen." % seed)
		return
	if int(edge.get("distance_blocks", 0)) != 1:
		failures.append("%s: beach edge to delta_queen must be 1 block, got %d." % [seed, int(edge.get("distance_blocks", 0))])
	var beach_edge_count := 0
	for edge_value in _copy_array(map_data.get("edges", [])):
		if typeof(edge_value) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = edge_value
		if str(candidate.get("a", "")) == "beach" or str(candidate.get("b", "")) == "beach":
			beach_edge_count += 1
	if beach_edge_count != 1:
		failures.append("%s: beach must only connect to delta_queen, saw %d beach edges." % [seed, beach_edge_count])


func _world_map_edge_between(map_data: Dictionary, a: String, b: String) -> Dictionary:
	for edge_value in _copy_array(map_data.get("edges", [])):
		if typeof(edge_value) != TYPE_DICTIONARY:
			continue
		var edge: Dictionary = edge_value
		var left := str(edge.get("a", "")).strip_edges()
		var right := str(edge.get("b", "")).strip_edges()
		if (left == a and right == b) or (left == b and right == a):
			return edge
	return {}


func _audit_environment_unique_object_classes(environment: Dictionary, seed: String, visit_index: int) -> void:
	var class_by_object_id := _unique_class_by_layout_object_id(environment)
	if class_by_object_id.is_empty():
		return
	var layout := _copy_dict(environment.get("layout", {}))
	var object_rects := _copy_dict(layout.get("object_rects", {}))
	var seen_classes: Dictionary = {}
	for object_id_value in object_rects.keys():
		var object_id := str(object_id_value)
		var unique_class := str(class_by_object_id.get(object_id, "")).strip_edges()
		if unique_class.is_empty():
			continue
		if seen_classes.has(unique_class):
			failures.append("%s visit %d %s: duplicate unique object class %s from %s and %s." % [
				seed,
				visit_index,
				str(environment.get("archetype_id", environment.get("id", ""))),
				unique_class,
				str(seen_classes.get(unique_class, "")),
				object_id,
			])
			return
		seen_classes[unique_class] = object_id


func _unique_class_by_layout_object_id(environment: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for event_id in _string_array(environment.get("event_ids", [])):
		var event_definition := library.event(event_id)
		var unique_class := str(event_definition.get("unique_object_class", "")).strip_edges()
		if not unique_class.is_empty() and not bool(event_definition.get("allow_duplicate_unique_class", false)):
			result["event:%s" % event_id] = unique_class
	var game_states := _copy_dict(environment.get("game_states", {}))
	for game_id in _string_array(environment.get("game_ids", [])):
		var machine := _copy_dict(game_states.get(game_id, {}))
		for hook_value in _copy_array(machine.get("environment_hooks", [])):
			if typeof(hook_value) != TYPE_DICTIONARY:
				continue
			var hook: Dictionary = hook_value
			var unique_class := str(hook.get("unique_object_class", "")).strip_edges()
			if unique_class.is_empty() or bool(hook.get("allow_duplicate_unique_class", false)):
				continue
			var object_id := str(hook.get("object_id", "")).strip_edges()
			if object_id.is_empty():
				var dialogue_id := str(hook.get("dialogue_id", "")).strip_edges()
				object_id = "dialogue:%s" % dialogue_id if not dialogue_id.is_empty() else "game_hook:%s:%s" % [game_id, str(hook.get("id", ""))]
			result[object_id] = unique_class
	return result


func _summarize_game_state(game_id: String, state: Dictionary) -> Dictionary:
	var summary := {
		"present": not state.is_empty(),
		"keys": _sorted_keys(state),
	}
	match game_id:
		"blackjack":
			var side_bets := []
			for side_bet in _copy_array(state.get("side_bets", [])):
				if typeof(side_bet) == TYPE_DICTIONARY:
					side_bets.append(str((side_bet as Dictionary).get("id", "")))
			summary["table_name"] = str(state.get("table_name", ""))
			summary["dealer_name"] = str(state.get("dealer_name", ""))
			summary["deck_count"] = int(state.get("deck_count", 0))
			summary["shoe_remaining"] = int(state.get("shoe_remaining", 0))
			summary["side_bets"] = side_bets
			summary["side_bet_count"] = side_bets.size()
			summary["patron_count"] = _copy_array(state.get("patrons", [])).size()
			summary["rules"] = _copy_dict(state.get("rules", {}))
		"pull_tabs":
			var deals := _copy_array(state.get("deals", []))
			var deal_summaries := []
			var total_remaining := 0
			var prices := []
			for index in range(deals.size()):
				if typeof(deals[index]) != TYPE_DICTIONARY:
					continue
				var deal: Dictionary = deals[index]
				total_remaining += int(deal.get("remaining", 0))
				prices.append(int(deal.get("price", 0)))
				deal_summaries.append({
					"index": index,
					"id": str(deal.get("id", "")),
					"display_name": str(deal.get("display_name", "")),
					"price": int(deal.get("price", 0)),
					"ticket_count": int(deal.get("ticket_count", 0)),
					"remaining": int(deal.get("remaining", 0)),
					"initial_removed_count": int(deal.get("initial_removed_count", 0)),
					"prize_count": _copy_array(deal.get("prizes", [])).size(),
				})
			var item_state := _copy_dict(state.get("item_state", {}))
			summary["deal_count"] = deals.size()
			summary["total_remaining"] = total_remaining
			summary["column_prices"] = prices
			summary["deals"] = deal_summaries
			summary["xray_target_count"] = _copy_array(item_state.get("xray_targets", [])).size()
		"slot":
			summary["machine_name"] = str(state.get("machine_name", state.get("name", "")))
			summary["jackpot_current"] = int(state.get("jackpot_current", 0))
			summary["jackpot_base"] = int(state.get("jackpot_base", 0))
			summary["bumper_goal"] = int(state.get("bumper_goal", 0))
			summary["reel_count"] = _copy_array(state.get("reels", [])).size()
		_:
			summary["schema"] = str(state.get("schema", ""))
	return summary


func _event_trigger_status(run_state: RunState) -> Array:
	var result: Array = []
	for event_id in _string_array(run_state.current_environment.get("event_ids", [])):
		var definition := library.event(event_id)
		if definition.is_empty():
			continue
		var module := EventModule.new()
		module.setup(definition)
		result.append({
			"id": event_id,
			"display_name": str(definition.get("display_name", event_id)),
			"trigger": _copy_dict(definition.get("trigger", {"type": "manual"})),
			"manual_now": module.can_trigger(run_state, run_state.current_environment),
			"timed_after_two_turns": module.can_trigger(run_state, run_state.current_environment, {"turns": 2}),
			"travel_trigger": module.can_trigger(run_state, run_state.current_environment, {"trigger": "travel"}),
		})
	return result


func _resolve_travel_unlock_events(run_state: RunState, path_rng: RngStream) -> Array:
	var resolved: Array = []
	for _pass_index in range(6):
		var enabled_travel := _enabled_travel_choices(run_state)
		var allow_bankroll_help := enabled_travel.is_empty()
		var candidate := _best_event_choice(run_state, allow_bankroll_help)
		if candidate.is_empty():
			break
		var event_id := str(candidate.get("event_id", ""))
		var choice_id := str(candidate.get("choice_id", ""))
		var definition := library.event(event_id)
		if definition.is_empty():
			break
		var module := EventModule.new()
		module.setup(definition)
		if not module.can_trigger(run_state, run_state.current_environment):
			break
		var before_next := _string_array(run_state.current_environment.get("next_archetypes", []))
		var before_bankroll := run_state.bankroll
		var before_heat := run_state.suspicion_level()
		var result := module.resolve(run_state, run_state.current_environment, choice_id)
		resolved.append({
			"event_id": event_id,
			"choice_id": choice_id,
			"reason": str(candidate.get("reason", "")),
			"score": int(candidate.get("score", 0)),
			"bankroll_before": before_bankroll,
			"bankroll_after": run_state.bankroll,
			"suspicion_before": before_heat,
			"suspicion_after": run_state.suspicion_level(),
			"next_archetypes_before": before_next,
			"next_archetypes_after": _string_array(run_state.current_environment.get("next_archetypes", [])),
			"message": str(result.get("message", "")),
		})
		if run_state.is_terminal() or path_rng == null:
			break
	return resolved


func _best_event_choice(run_state: RunState, allow_bankroll_help: bool) -> Dictionary:
	var best := {}
	for event_id in _string_array(run_state.current_environment.get("event_ids", [])):
		var definition := library.event(event_id)
		if definition.is_empty():
			continue
		var module := EventModule.new()
		module.setup(definition)
		if not module.can_trigger(run_state, run_state.current_environment):
			continue
		for choice in module.choices():
			if typeof(choice) != TYPE_DICTIONARY:
				continue
			var choice_data: Dictionary = choice
			var score_data := _event_choice_score(run_state, choice_data, allow_bankroll_help)
			var score := int(score_data.get("score", 0))
			if score <= 0:
				continue
			if best.is_empty() or score > int(best.get("score", 0)):
				best = {
					"event_id": event_id,
					"choice_id": str(choice_data.get("id", "")),
					"score": score,
					"reason": str(score_data.get("reason", "")),
				}
	return best


func _event_choice_score(run_state: RunState, choice: Dictionary, allow_bankroll_help: bool) -> Dictionary:
	var consequences := _copy_dict(choice.get("consequences", {}))
	var current_targets := _travel_target_ids(run_state)
	var route_targets := _route_targets_from_consequences(consequences)
	var score := 0
	var reasons: Array = []
	var new_target_count := 0
	for target in route_targets:
		if not current_targets.has(target):
			new_target_count += 1
	if new_target_count > 0:
		score += 40 + new_target_count * 15
		reasons.append("adds %d new route target(s)" % new_target_count)
	elif not route_targets.is_empty():
		score += 12
		reasons.append("refreshes route choices")
	var flags := _copy_dict(consequences.get("flags", consequences.get("flags_set", {})))
	for key in flags.keys():
		if str(key) == "underground_tip" and bool(flags[key]) and not bool(run_state.narrative_flags.get("underground_tip", false)):
			score += 65
			reasons.append("unlocks underground route condition")
	if allow_bankroll_help and int(consequences.get("bankroll_delta", 0)) > 0:
		score += int(consequences.get("bankroll_delta", 0))
		reasons.append("restores travel bankroll")
	if score > 0 and int(consequences.get("suspicion_delta", 0)) <= 0:
		score += 3
	return {"score": score, "reason": "; ".join(reasons)}


func _route_targets_from_consequences(consequences: Dictionary) -> Array:
	var targets: Array = []
	for id in _string_array(consequences.get("travel_hooks_add", [])):
		if not targets.has(id):
			targets.append(id)
	for id in _string_array(consequences.get("set_next_archetypes", [])):
		if not targets.has(id):
			targets.append(id)
	for id in _string_array(consequences.get("add_next_archetypes", [])):
		if not targets.has(id):
			targets.append(id)
	var travel_changes := _copy_dict(consequences.get("travel_changes", {}))
	for id in _string_array(travel_changes.get("set_next_archetypes", [])):
		if not targets.has(id):
			targets.append(id)
	for id in _string_array(travel_changes.get("add_next_archetypes", [])):
		if not targets.has(id):
			targets.append(id)
	return targets


func _pick_travel_choice(run_state: RunState, path_rng: RngStream) -> Dictionary:
	var enabled := _enabled_travel_choices(run_state)
	if enabled.is_empty():
		return {}
	var grand_choices: Array = []
	for choice in enabled:
		if str((choice as Dictionary).get("id", "")) == "grand_casino":
			grand_choices.append(choice)
	if not grand_choices.is_empty():
		return (grand_choices[0] as Dictionary).duplicate(true)
	return (enabled[path_rng.randi_range(0, enabled.size() - 1)] as Dictionary).duplicate(true)


func _enabled_travel_choices(run_state: RunState) -> Array:
	var enabled: Array = []
	for choice in _travel_choices(run_state, false):
		if bool((choice as Dictionary).get("enabled", false)):
			enabled.append(choice)
	return enabled


func _travel_choices(run_state: RunState, include_hidden: bool) -> Array:
	var choices: Array = []
	for target_id in _travel_target_ids(run_state):
		var route := generator.world_route_for_target(run_state, target_id)
		var archetype := _archetype(target_id)
		var status := run_state.travel_route_status(route)
		if bool(status.get("hidden", false)) and not include_hidden:
			continue
		var choice := {
			"id": target_id,
			"label": str(route.get("label", _travel_label_from_archetype(archetype, target_id))),
			"kind": str(archetype.get("kind", "")),
			"tier": int(archetype.get("tier", 1)),
			"enabled": bool(status.get("available", true)),
			"hidden": bool(status.get("hidden", false)),
			"disabled_reason": str(status.get("disabled_reason", "")),
			"cost": int(status.get("cost", route.get("cost", 0))),
			"risk": str(route.get("risk", "")),
			"distance": str(status.get("distance", route.get("distance", ""))),
			"risk_decay": int(status.get("risk_decay", route.get("risk_decay", 0))),
			"suspicion_delta": int(status.get("suspicion_delta", route.get("suspicion_delta", 0))),
			"risk_text": str(status.get("risk_text", "")),
			"risk_event": _copy_dict(status.get("risk_event", {})),
			"unlock_conditions": _copy_array(status.get("unlock_conditions", [])),
			"travel_lock_remaining": int(status.get("travel_lock_remaining", 0)),
			"availability_turn": int(status.get("availability_turn", -1)),
		}
		choices.append(choice)
	return choices


func _current_travel_lock_remaining(run_state: RunState) -> int:
	if run_state == null or run_state.current_environment.is_empty():
		return 0
	return maxi(0, int(run_state.current_environment.get("travel_lock_remaining", 0)))


func _travel_to(run_state: RunState, choice: Dictionary) -> Dictionary:
	var target_id := str(choice.get("id", ""))
	var route := generator.world_route_for_target(run_state, target_id)
	var previous_environment := run_state.current_environment.duplicate(true)
	var previous_bankroll := run_state.bankroll
	var previous_heat := run_state.suspicion_level()
	var route_risk := run_state.travel_route_risk(route, target_id)
	var travel_heat := run_state.begin_travel_suspicion_decay(route, target_id)
	generator.next_environment(run_state, target_id)
	var travel_decay := run_state.finish_travel_suspicion_decay(travel_heat)
	var destination_name := str(run_state.current_environment.get("display_name", target_id))
	var result := _travel_result(run_state, target_id, destination_name, route, previous_environment, run_state.current_environment, travel_decay, route_risk)
	GameModule.apply_result(run_state, result)
	return {
		"target_id": target_id,
		"label": str(choice.get("label", target_id)),
		"from_environment_id": str(previous_environment.get("id", "")),
		"from_archetype_id": str(previous_environment.get("archetype_id", "")),
		"to_environment_id": str(run_state.current_environment.get("id", "")),
		"to_archetype_id": str(run_state.current_environment.get("archetype_id", "")),
		"cost": int(choice.get("cost", 0)),
		"bankroll_before": previous_bankroll,
		"bankroll_after": run_state.bankroll,
		"suspicion_before": previous_heat,
		"suspicion_after": run_state.suspicion_level(),
		"travel_decay": travel_decay,
		"route_risk": route_risk,
		"message": str(result.get("message", "")),
	}


func _travel_result(run_state: RunState, target_id: String, destination_name: String, route: Dictionary, previous_environment: Dictionary, destination_environment: Dictionary, travel_decay: Dictionary, route_risk: Dictionary) -> Dictionary:
	var route_status := run_state.travel_route_status(route)
	var cost := int(route_status.get("cost", 0))
	var suspicion_delta := int(route_status.get("suspicion_delta", 0))
	var risk_bankroll_delta := int(route_risk.get("bankroll_delta", 0)) if bool(route_risk.get("triggered", false)) else 0
	var risk_suspicion_delta := int(route_risk.get("suspicion_delta", 0)) if bool(route_risk.get("triggered", false)) else 0
	var cooled := int(travel_decay.get("cooled", 0))
	var risk_decay := int(travel_decay.get("risk_decay", route_status.get("risk_decay", 0)))
	var message := "Traveled to %s." % destination_name
	var detail_parts: Array = []
	if cost > 0:
		detail_parts.append("Route cost %d" % cost)
	if cooled > 0:
		detail_parts.append("distance shakes most heat" if risk_decay >= 70 else "distance shakes some heat")
	var drunk_delta := int(travel_decay.get("drunk_delta", 0))
	if drunk_delta < 0:
		detail_parts.append("travel sobers you %+d" % drunk_delta)
	if suspicion_delta > 0:
		detail_parts.append("risk +%d" % suspicion_delta)
	if risk_bankroll_delta != 0 or risk_suspicion_delta != 0:
		var risk_label := str(route_risk.get("label", "route risk"))
		var risk_detail := "%s" % risk_label
		if risk_bankroll_delta != 0:
			risk_detail += " %+d" % risk_bankroll_delta
		if risk_suspicion_delta > 0:
			risk_detail += ", heat +%d" % risk_suspicion_delta
		detail_parts.append(risk_detail)
	if not detail_parts.is_empty():
		message = "%s %s." % [message, ", ".join(detail_parts)]
	var total_bankroll_delta := -cost + risk_bankroll_delta
	var total_suspicion_delta := suspicion_delta + risk_suspicion_delta
	var story_entry := {
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
		"route_suspicion_delta": suspicion_delta,
		"travel_distance": str(travel_decay.get("distance", route_status.get("distance", ""))),
		"risk_decay": risk_decay,
		"risk_cooled": cooled,
		"route_risk": route_risk.duplicate(true),
		"drunk_delta": drunk_delta,
		"drunk_after": int(travel_decay.get("drunk_after", run_state.drunk_level)),
		"message": message,
	}
	var story_entries: Array = [story_entry]
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
			"message": str(route_risk.get("message", "The route risk catches you.")),
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


func _travel_target_ids(run_state: RunState) -> Array:
	if run_state.has_world_map():
		return WorldMapScript.neighbor_ids(run_state.world_map, run_state.current_world_node_id(), true)
	var result: Array = []
	for source in [
		run_state.current_environment.get("next_archetypes", []),
		run_state.current_environment.get("travel_hooks", []),
	]:
		for target_id in _string_array(source):
			if not result.has(target_id):
				result.append(target_id)
	return result


func _build_aggregate(run_count: int, visits_per_run: int, seed_prefix: String) -> Dictionary:
	var aggregate := {
		"run_count": run_count,
		"visits_per_run_target": visits_per_run,
		"seed_prefix": seed_prefix,
		"environment_visit_count": records.size(),
		"travel_count": travel_records.size(),
		"events_resolved_for_travel": 0,
		"stopped_reasons": {},
		"archetypes": {},
		"kinds": {},
		"tiers": {},
		"moods": {},
		"games": {},
		"events": {},
		"event_resolutions": {},
		"items": {},
		"item_prices": {},
		"services": {},
		"lenders": {},
		"travel_targets_generated": {},
		"travel_targets_available": {},
		"travel_targets_locked": {},
		"travel_targets_selected": {},
		"travel_risk_events": {},
		"overall_objects": {},
		"archetype_content": {},
		"run_presence": {},
	}
	var run_presence := _empty_presence_groups()
	for summary in run_summaries:
		if typeof(summary) != TYPE_DICTIONARY:
			continue
		_count_key(aggregate["stopped_reasons"], str((summary as Dictionary).get("stopped_reason", "unknown")))
	for record in records:
		if typeof(record) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = record
		var run_index := int(data.get("run_index", 0))
		var archetype_id := str(data.get("archetype_id", "unknown"))
		_count_key(aggregate["archetypes"], archetype_id)
		_count_key(aggregate["overall_objects"], "environment:%s" % archetype_id)
		_mark_presence(run_presence["archetypes"], run_index, archetype_id)
		_count_key(aggregate["kinds"], str(data.get("kind", "unknown")))
		_count_key(aggregate["tiers"], str(data.get("tier", 1)))
		_count_key(aggregate["moods"], str(data.get("mood", "unknown")))
		_count_archetype_content(aggregate, archetype_id, "visits", archetype_id)
		for game_id in _string_array(data.get("games", [])):
			_count_key(aggregate["games"], game_id)
			_count_key(aggregate["overall_objects"], "game:%s" % game_id)
			_mark_presence(run_presence["games"], run_index, game_id)
			_count_archetype_content(aggregate, archetype_id, "games", game_id)
		for event_id in _string_array(data.get("events", [])):
			_count_key(aggregate["events"], event_id)
			_count_key(aggregate["overall_objects"], "event:%s" % event_id)
			_mark_presence(run_presence["events"], run_index, event_id)
			_count_archetype_content(aggregate, archetype_id, "events", event_id)
		for offer in _copy_array(data.get("items", [])):
			if typeof(offer) != TYPE_DICTIONARY:
				continue
			var item_id := str((offer as Dictionary).get("id", ""))
			_count_key(aggregate["items"], item_id)
			_count_key(aggregate["overall_objects"], "item:%s" % item_id)
			_mark_presence(run_presence["items"], run_index, item_id)
			_count_archetype_content(aggregate, archetype_id, "items", item_id)
			_track_price(aggregate["item_prices"], item_id, int((offer as Dictionary).get("price", 0)))
		for service_id in _string_array(data.get("services", [])):
			_count_key(aggregate["services"], service_id)
			_count_key(aggregate["overall_objects"], "service:%s" % service_id)
			_mark_presence(run_presence["services"], run_index, service_id)
			_count_archetype_content(aggregate, archetype_id, "services", service_id)
		for lender_id in _string_array(data.get("lenders", [])):
			_count_key(aggregate["lenders"], lender_id)
			_count_key(aggregate["overall_objects"], "lender:%s" % lender_id)
			_mark_presence(run_presence["lenders"], run_index, lender_id)
			_count_archetype_content(aggregate, archetype_id, "lenders", lender_id)
		var recorded_travel_object := false
		for choice in _copy_array(data.get("travel_after_events", [])):
			if typeof(choice) != TYPE_DICTIONARY:
				continue
			var target_id := str((choice as Dictionary).get("id", ""))
			_count_key(aggregate["travel_targets_generated"], target_id)
			if not recorded_travel_object:
				_count_key(aggregate["overall_objects"], "travel:leave")
				recorded_travel_object = true
			if bool((choice as Dictionary).get("enabled", false)):
				_count_key(aggregate["travel_targets_available"], target_id)
			else:
				_count_key(aggregate["travel_targets_locked"], target_id)
		var resolved_events := _copy_array(data.get("events_resolved_for_travel", []))
		aggregate["events_resolved_for_travel"] = int(aggregate.get("events_resolved_for_travel", 0)) + resolved_events.size()
		for resolved in resolved_events:
			if typeof(resolved) != TYPE_DICTIONARY:
				continue
			var key := "%s:%s" % [str((resolved as Dictionary).get("event_id", "")), str((resolved as Dictionary).get("choice_id", ""))]
			_count_key(aggregate["event_resolutions"], key)
	for travel in travel_records:
		if typeof(travel) != TYPE_DICTIONARY:
			continue
		var travel_data: Dictionary = travel
		_count_key(aggregate["travel_targets_selected"], str(travel_data.get("target_id", "")))
		var route_risk := _copy_dict(travel_data.get("route_risk", {}))
		if bool(route_risk.get("triggered", false)):
			_count_key(aggregate["travel_risk_events"], str(route_risk.get("id", "travel_risk")))
	aggregate["run_presence"] = _presence_counts(run_presence)
	_finalize_price_stats(aggregate["item_prices"])
	return aggregate


func _write_json(output_path: String, report: Dictionary) -> void:
	var global_path := ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(global_path.get_base_dir())
	var file := FileAccess.open(global_path, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write JSON report to %s." % global_path)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()


func _write_markdown(output_path: String, report: Dictionary) -> void:
	var global_path := ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(global_path.get_base_dir())
	var markdown := _build_markdown(report)
	var file := FileAccess.open(global_path, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write Markdown report to %s." % global_path)
		return
	file.store_string(markdown)
	file.close()


func _build_markdown(report: Dictionary) -> String:
	var aggregate := _copy_dict(report.get("aggregate", {}))
	var env_count := maxi(1, int(aggregate.get("environment_visit_count", 0)))
	var run_count := maxi(1, int(aggregate.get("run_count", 0)))
	var lines: Array = []
	lines.append("# Environment Generation Audit")
	lines.append("")
	lines.append("Generated by `tools/environment_generation_audit.gd`.")
	lines.append("")
	lines.append("## Method")
	for note in _method_notes():
		lines.append("- %s" % note)
	lines.append("- Seed prefix: `%s`." % str(report.get("seed_prefix", "")))
	lines.append("- Raw data: `res://.tmp/environment_generation_audit/report.json`.")
	lines.append("")
	lines.append("## Summary")
	lines.append("")
	lines.append("| Metric | Value |")
	lines.append("| --- | ---: |")
	lines.append("| Unique seed runs | %d |" % int(report.get("run_count", 0)))
	lines.append("| Target location visits per run | %d |" % int(report.get("visits_per_run_target", 0)))
	lines.append("| Generated location samples | %d |" % int(aggregate.get("environment_visit_count", 0)))
	lines.append("| Travel transitions | %d |" % int(aggregate.get("travel_count", 0)))
	lines.append("| Travel risk events | %d |" % _count_total(aggregate.get("travel_risk_events", {})))
	lines.append("| Event choices resolved for travel | %d |" % int(aggregate.get("events_resolved_for_travel", 0)))
	lines.append("| Failures | %d |" % int(report.get("failure_count", 0)))
	lines.append("| Warnings | %d |" % int(report.get("warning_count", 0)))
	lines.append("")
	lines.append("## Environment Visits")
	lines.append("")
	lines.append(_count_table(aggregate.get("archetypes", {}), env_count, run_count, aggregate.get("run_presence", {}).get("archetypes", {}), "Environment"))
	lines.append("")
	lines.append("```mermaid")
	lines.append("pie showData")
	lines.append("    title Environment visit share")
	for pair in _ranked_pairs(aggregate.get("archetypes", {}), 12):
		lines.append("    \"%s\" : %d" % [str(pair.get("key", "")), int(pair.get("count", 0))])
	lines.append("```")
	lines.append("")
	lines.append("## Generated Games")
	lines.append("")
	lines.append(_count_table(aggregate.get("games", {}), env_count, run_count, aggregate.get("run_presence", {}).get("games", {}), "Game"))
	lines.append("")
	lines.append("## Generated Events")
	lines.append("")
	lines.append(_count_table(aggregate.get("events", {}), env_count, run_count, aggregate.get("run_presence", {}).get("events", {}), "Event"))
	lines.append("")
	lines.append("### Event Choices Resolved For Travel")
	lines.append("")
	lines.append(_simple_count_table(aggregate.get("event_resolutions", {}), int(aggregate.get("events_resolved_for_travel", 0)), "Event choice"))
	lines.append("")
	lines.append("## Item Offers")
	lines.append("")
	lines.append(_item_table(aggregate, env_count, run_count))
	lines.append("")
	lines.append("## Services And Lenders")
	lines.append("")
	lines.append("### Services")
	lines.append("")
	lines.append(_count_table(aggregate.get("services", {}), env_count, run_count, aggregate.get("run_presence", {}).get("services", {}), "Service"))
	lines.append("")
	lines.append("### Lenders")
	lines.append("")
	lines.append(_count_table(aggregate.get("lenders", {}), env_count, run_count, aggregate.get("run_presence", {}).get("lenders", {}), "Lender"))
	lines.append("")
	lines.append("## Travel Availability")
	lines.append("")
	lines.append("### Available After Event Policy")
	lines.append("")
	lines.append(_simple_count_table(aggregate.get("travel_targets_available", {}), env_count, "Route"))
	lines.append("")
	lines.append("### Locked Or Hidden After Event Policy")
	lines.append("")
	lines.append(_simple_count_table(aggregate.get("travel_targets_locked", {}), env_count, "Route"))
	lines.append("")
	lines.append("### Selected Routes")
	lines.append("")
	lines.append(_simple_count_table(aggregate.get("travel_targets_selected", {}), maxi(1, int(aggregate.get("travel_count", 0))), "Route"))
	lines.append("")
	lines.append("### Travel Risk Events")
	lines.append("")
	lines.append(_simple_count_table(aggregate.get("travel_risk_events", {}), maxi(1, _count_total(aggregate.get("travel_risk_events", {}))), "Risk event"))
	lines.append("")
	lines.append("## Most Common Objects Overall")
	lines.append("")
	lines.append(_simple_count_table(aggregate.get("overall_objects", {}), env_count, "Object", 20))
	lines.append("")
	lines.append("## Content By Environment")
	lines.append("")
	lines.append(_archetype_content_sections(aggregate))
	lines.append("")
	lines.append("## Run Stops")
	lines.append("")
	lines.append(_simple_count_table(aggregate.get("stopped_reasons", {}), run_count, "Reason"))
	lines.append("")
	lines.append("## Notes")
	lines.append("")
	lines.append("- Percentages are based on generated location samples unless a column is labeled run rate.")
	lines.append("- Grand Casino can appear as a travel target before it is affordable. In this no-game travel audit, locked Grand Casino availability is expected unless events create enough bankroll.")
	lines.append("- The JSON output includes every sampled environment, every generated game-state summary, every route choice, and every travel transition.")
	lines.append("")
	return "\n".join(lines)


func _count_table(counts_value: Variant, env_count: int, run_count: int, run_presence_value: Variant, label: String) -> String:
	var counts := _copy_dict(counts_value)
	if counts.is_empty():
		return "_None observed._"
	var run_presence := _copy_dict(run_presence_value)
	var lines: Array = []
	lines.append("| %s | Count | Env rate | Run rate | Chart |" % label)
	lines.append("| --- | ---: | ---: | ---: | --- |")
	for pair in _ranked_pairs(counts, 50):
		var key := str(pair.get("key", ""))
		var count := int(pair.get("count", 0))
		var run_hits := int(run_presence.get(key, 0))
		lines.append("| `%s` | %d | %s | %s | `%s` |" % [
			key,
			count,
			_percent(float(count) / float(maxi(1, env_count))),
			_percent(float(run_hits) / float(maxi(1, run_count))),
			_bar(float(count) / float(maxi(1, env_count))),
		])
	return "\n".join(lines)


func _simple_count_table(counts_value: Variant, denominator: int, label: String, limit: int = 50) -> String:
	var counts := _copy_dict(counts_value)
	if counts.is_empty():
		return "_None observed._"
	var lines: Array = []
	lines.append("| %s | Count | Rate | Chart |" % label)
	lines.append("| --- | ---: | ---: | --- |")
	for pair in _ranked_pairs(counts, limit):
		var count := int(pair.get("count", 0))
		var rate := float(count) / float(maxi(1, denominator))
		lines.append("| `%s` | %d | %s | `%s` |" % [str(pair.get("key", "")), count, _percent(rate), _bar(rate)])
	return "\n".join(lines)


func _count_total(counts_value: Variant) -> int:
	var counts := _copy_dict(counts_value)
	var total := 0
	for key in counts.keys():
		total += int(counts.get(key, 0))
	return total


func _item_table(aggregate: Dictionary, env_count: int, run_count: int) -> String:
	var counts := _copy_dict(aggregate.get("items", {}))
	if counts.is_empty():
		return "_None observed._"
	var run_presence := _copy_dict(_copy_dict(aggregate.get("run_presence", {})).get("items", {}))
	var prices := _copy_dict(aggregate.get("item_prices", {}))
	var lines: Array = []
	lines.append("| Item | Count | Env rate | Run rate | Avg price | Price range | Chart |")
	lines.append("| --- | ---: | ---: | ---: | ---: | ---: | --- |")
	for pair in _ranked_pairs(counts, 50):
		var key := str(pair.get("key", ""))
		var count := int(pair.get("count", 0))
		var price := _copy_dict(prices.get(key, {}))
		var avg := float(price.get("average", 0.0))
		var min_price := int(price.get("min", 0))
		var max_price := int(price.get("max", 0))
		lines.append("| `%s` | %d | %s | %s | %.1f | %d-%d | `%s` |" % [
			key,
			count,
			_percent(float(count) / float(maxi(1, env_count))),
			_percent(float(int(run_presence.get(key, 0))) / float(maxi(1, run_count))),
			avg,
			min_price,
			max_price,
			_bar(float(count) / float(maxi(1, env_count))),
		])
	return "\n".join(lines)


func _archetype_content_sections(aggregate: Dictionary) -> String:
	var content := _copy_dict(aggregate.get("archetype_content", {}))
	if content.is_empty():
		return "_No archetype content recorded._"
	var sections: Array = []
	var archetypes := content.keys()
	archetypes.sort()
	for archetype_id in archetypes:
		var data := _copy_dict(content.get(archetype_id, {}))
		sections.append("### `%s`" % archetype_id)
		sections.append("")
		for group in ["games", "events", "items", "services", "lenders"]:
			var counts := _copy_dict(data.get(group, {}))
			var top := _top_inline(counts, 8)
			sections.append("- %s: %s" % [group.capitalize(), top if not top.is_empty() else "none"])
		sections.append("")
	return "\n".join(sections)


func _top_inline(counts: Dictionary, limit: int) -> String:
	var parts: Array = []
	for pair in _ranked_pairs(counts, limit):
		parts.append("`%s` (%d)" % [str(pair.get("key", "")), int(pair.get("count", 0))])
	return ", ".join(parts)


func _print_summary(output_json: String, output_markdown: String, aggregate: Dictionary) -> void:
	print("Environment generation audit complete.")
	print("Environment samples: %d" % int(aggregate.get("environment_visit_count", 0)))
	print("Travel transitions: %d" % int(aggregate.get("travel_count", 0)))
	print("Markdown report: %s" % ProjectSettings.globalize_path(output_markdown))
	print("JSON report: %s" % ProjectSettings.globalize_path(output_json))
	if failures.is_empty():
		print("Environment generation audit passed.")
	else:
		for failure in failures:
			push_error(failure)


func _method_notes() -> Array:
	return [
		"100 unique randomly generated seed runs by default.",
		"Each run targets six generated location visits.",
		"No game is entered or resolved; game state is only generated by the environment generator.",
		"No items, services, or lenders are purchased or used.",
		"Event policy resolves only choices that add/replace travel targets, set the underground travel flag, or restore bankroll when no route is otherwise enabled.",
		"Travel-locked venues advance their lock countdown when no route is enabled, simulating non-game ride actions for audit continuity.",
		"Travel uses the same route status, route cost, suspicion decay, and travel result application path as the Foundation UI.",
	]


func _empty_presence_groups() -> Dictionary:
	return {
		"archetypes": {},
		"games": {},
		"events": {},
		"items": {},
		"services": {},
		"lenders": {},
	}


func _presence_counts(presence: Dictionary) -> Dictionary:
	var result := {}
	for group in presence.keys():
		var group_result := {}
		var group_presence := _copy_dict(presence.get(group, {}))
		for key in group_presence.keys():
			group_result[key] = _copy_dict(group_presence.get(key, {})).size()
		result[group] = group_result
	return result


func _mark_presence(presence_group: Dictionary, run_index: int, key: String) -> void:
	if key.is_empty():
		return
	var runs := _copy_dict(presence_group.get(key, {}))
	runs[str(run_index)] = true
	presence_group[key] = runs


func _count_archetype_content(aggregate: Dictionary, archetype_id: String, group: String, key: String) -> void:
	var content := _copy_dict(aggregate.get("archetype_content", {}))
	var archetype := _copy_dict(content.get(archetype_id, {}))
	var counts := _copy_dict(archetype.get(group, {}))
	_count_key(counts, key)
	archetype[group] = counts
	content[archetype_id] = archetype
	aggregate["archetype_content"] = content


func _track_price(price_stats: Dictionary, item_id: String, price: int) -> void:
	if item_id.is_empty():
		return
	var data := _copy_dict(price_stats.get(item_id, {}))
	if data.is_empty():
		data = {"count": 0, "sum": 0, "min": price, "max": price}
	data["count"] = int(data.get("count", 0)) + 1
	data["sum"] = int(data.get("sum", 0)) + price
	data["min"] = mini(int(data.get("min", price)), price)
	data["max"] = maxi(int(data.get("max", price)), price)
	price_stats[item_id] = data


func _finalize_price_stats(price_stats: Dictionary) -> void:
	for item_id in price_stats.keys():
		var data := _copy_dict(price_stats.get(item_id, {}))
		var count := maxi(1, int(data.get("count", 0)))
		data["average"] = float(int(data.get("sum", 0))) / float(count)
		price_stats[item_id] = data


func _ranked_pairs(counts_value: Variant, limit: int) -> Array:
	var counts := _copy_dict(counts_value)
	var pairs: Array = []
	for key in counts.keys():
		pairs.append({"key": str(key), "count": int(counts[key])})
	pairs.sort_custom(Callable(self, "_sort_count_desc"))
	if limit > 0 and pairs.size() > limit:
		return pairs.slice(0, limit)
	return pairs


func _sort_count_desc(a: Dictionary, b: Dictionary) -> bool:
	var count_a := int(a.get("count", 0))
	var count_b := int(b.get("count", 0))
	if count_a == count_b:
		return str(a.get("key", "")) < str(b.get("key", ""))
	return count_a > count_b


func _count_key(counts: Dictionary, key: String) -> void:
	if key.is_empty():
		return
	counts[key] = int(counts.get(key, 0)) + 1


func _item_offer_records(offers_value: Variant) -> Array:
	var result: Array = []
	for offer in _copy_array(offers_value):
		if typeof(offer) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = offer
		result.append({
			"id": str(data.get("id", "")),
			"display_name": str(data.get("display_name", "")),
			"price": int(data.get("price", 0)),
			"price_min": int(data.get("price_min", 0)),
			"price_max": int(data.get("price_max", 0)),
		})
	return result


func _item_ids_from_offers(offers_value: Variant) -> Array:
	var result: Array = []
	for offer in _copy_array(offers_value):
		if typeof(offer) != TYPE_DICTIONARY:
			continue
		var item_id := str((offer as Dictionary).get("id", ""))
		if not item_id.is_empty():
			result.append(item_id)
	return result


func _archetype(archetype_id: String) -> Dictionary:
	for archetype in library.environment_archetypes:
		if typeof(archetype) == TYPE_DICTIONARY and str((archetype as Dictionary).get("id", "")) == archetype_id:
			return (archetype as Dictionary).duplicate(true)
	return {}


func _travel_label_from_archetype(archetype: Dictionary, fallback_id: String) -> String:
	var nouns := _copy_array(archetype.get("name_nouns", []))
	if not nouns.is_empty():
		return str(nouns[0])
	return fallback_id.replace("_", " ").capitalize()


func _percent(value: float) -> String:
	return "%.1f%%" % (value * 100.0)


func _bar(value: float, width: int = 24) -> String:
	var filled := clampi(int(round(value * float(width))), 0, width)
	var text := ""
	for index in range(width):
		text += "#" if index < filled else "."
	return text


func _sorted_keys(value: Dictionary) -> Array:
	var keys := value.keys()
	keys.sort()
	var result: Array = []
	for key in keys:
		result.append(str(key))
	return result


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		var id := str(entry)
		if not id.is_empty():
			result.append(id)
	return result


func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
